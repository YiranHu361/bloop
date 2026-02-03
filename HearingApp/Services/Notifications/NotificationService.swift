import Foundation
import UserNotifications

/// Service for managing local notifications
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false

    private let center = UNUserNotificationCenter.current()
    private var notificationCooldowns: [Int: Date] = [:] // threshold -> last notification time
    private let cooldownInterval: TimeInterval = 3600 // 1 hour between same threshold notifications
    private let cooldownStorageKey = "notification_cooldowns"

    private override init() {
        super.init()
        center.delegate = self
        loadPersistedCooldowns()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Cooldown Persistence

    /// Codable wrapper for notification cooldowns to ensure type-safe persistence
    private struct CooldownEntry: Codable {
        let threshold: Int
        let lastNotificationDate: Date
    }

    private func loadPersistedCooldowns() {
        guard let data = UserDefaults.standard.data(forKey: cooldownStorageKey) else {
            return
        }

        do {
            let entries = try JSONDecoder().decode([CooldownEntry].self, from: data)
            notificationCooldowns = entries.reduce(into: [:]) { result, entry in
                result[entry.threshold] = entry.lastNotificationDate
            }
        } catch {
            AppLogger.logWarning("Failed to decode cooldowns, resetting: \(error.localizedDescription)", context: "loadPersistedCooldowns", logger: AppLogger.notifications)
            notificationCooldowns = [:]
        }
    }

    private func persistCooldowns() {
        let entries = notificationCooldowns.map { CooldownEntry(threshold: $0.key, lastNotificationDate: $0.value) }

        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: cooldownStorageKey)
        } catch {
            AppLogger.logError(error, context: "persistCooldowns", logger: AppLogger.notifications)
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            AppLogger.logError(error, context: "requestAuthorization", logger: AppLogger.notifications)
            isAuthorized = false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - Threshold Notifications

    /// Clean up old cooldown entries to prevent memory buildup
    private func cleanupOldCooldowns() {
        let now = Date()
        notificationCooldowns = notificationCooldowns.filter { _, lastTime in
            now.timeIntervalSince(lastTime) < cooldownInterval * 2
        }
    }

    /// Check current dose and send notification if threshold crossed
    func checkAndNotify(for dosePercent: Double) async {
        guard isAuthorized else { return }

        cleanupOldCooldowns()

        // Check each threshold
        if dosePercent >= 100 {
            await sendThresholdNotification(threshold: 100, dosePercent: dosePercent)
        } else if dosePercent >= 80 {
            await sendThresholdNotification(threshold: 80, dosePercent: dosePercent)
        } else if dosePercent >= 50 {
            await sendThresholdNotification(threshold: 50, dosePercent: dosePercent)
        }
    }

    func checkAndNotify(
        for dosePercent: Double,
        limit: Int,
        warn50: Bool,
        warn80: Bool,
        warn100: Bool
    ) async {
        guard isAuthorized else { return }

        cleanupOldCooldowns()

        let limitValue = Double(limit)
        let threshold50 = limitValue * 0.5
        let threshold80 = limitValue * 0.8
        let threshold100 = limitValue

        if warn100, dosePercent >= threshold100 {
            await sendThresholdNotification(threshold: 100, dosePercent: dosePercent)
        } else if warn80, dosePercent >= threshold80 {
            await sendThresholdNotification(threshold: 80, dosePercent: dosePercent)
        } else if warn50, dosePercent >= threshold50 {
            await sendThresholdNotification(threshold: 50, dosePercent: dosePercent)
        }
    }

    private func sendThresholdNotification(threshold: Int, dosePercent: Double) async {
        // Check cooldown
        if let lastNotification = notificationCooldowns[threshold],
           Date().timeIntervalSince(lastNotification) < cooldownInterval {
            return // Still in cooldown
        }

        let content = UNMutableNotificationContent()

        // Try to get personalized message first
        let personalizedMessage = await MainActor.run {
            PersonalizationService.shared.getPersonalizedMessage(for: threshold, dosePercent: dosePercent)
        }

        switch threshold {
        case 100:
            content.title = "Daily Limit Reached"
            content.body = personalizedMessage ?? "You've used 100% of your daily sound allowance. Consider giving your ears a break."
            content.sound = .default
        case 80:
            content.title = "Approaching Limit"
            content.body = personalizedMessage ?? "You've used 80% of your daily sound allowance. Try lowering your volume."
            content.sound = .default
        case 50:
            content.title = "Halfway There"
            content.body = personalizedMessage ?? "You've used 50% of your daily sound allowance."
            content.sound = nil // Silent for 50%
        default:
            return
        }

        content.categoryIdentifier = "DOSE_THRESHOLD"
        content.threadIdentifier = "dose-alerts"

        let request = UNNotificationRequest(
            identifier: "dose-threshold-\(threshold)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
            notificationCooldowns[threshold] = Date()
            persistCooldowns()
        } catch {
            AppLogger.logError(error, context: "sendThresholdNotification(\(threshold))", logger: AppLogger.notifications)
        }
    }

    // MARK: - Actionable Notifications

    /// Send an actionable notification with remaining time and context
    func sendActionableNotification(
        dosePercent: Double,
        currentLevel: Double?,
        doseModel: DoseModel
    ) async {
        guard isAuthorized else { return }

        // Calculate remaining time
        let calculator = DoseCalculator(model: doseModel)
        let level = currentLevel ?? 80.0 // Use 80 dB as default estimate
        let remainingTime = calculator.remainingSafeTime(currentDosePercent: dosePercent, at: level)

        // Determine which notification to send based on context
        let timeContext = ActionableNotificationBuilder.TimeContext.current

        // Check cooldown for actionable notifications (separate from threshold cooldowns)
        let actionableCooldownKey = AppConfig.NotificationCooldownKey.actionable
        if let lastNotification = notificationCooldowns[actionableCooldownKey],
           Date().timeIntervalSince(lastNotification) < cooldownInterval {
            return
        }

        // Choose notification type based on dose level
        let content: UNMutableNotificationContent
        if dosePercent >= 100 {
            content = ActionableNotificationBuilder.buildEnhancedThresholdNotification(
                threshold: 100,
                dosePercent: dosePercent,
                remainingTime: remainingTime,
                currentLevel: currentLevel
            )
        } else if dosePercent >= 80 {
            content = ActionableNotificationBuilder.buildRemainingTimeNotification(
                dosePercent: dosePercent,
                remainingTime: remainingTime,
                currentLevel: currentLevel
            )
        } else if dosePercent >= 50 {
            // At 50%, send context-aware notification
            content = ActionableNotificationBuilder.buildContextAwareNotification(
                dosePercent: dosePercent,
                remainingTime: remainingTime
            )
        } else {
            return // Don't send notifications below 50%
        }

        let request = UNNotificationRequest(
            identifier: "actionable-\(timeContext.rawValue)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            notificationCooldowns[actionableCooldownKey] = Date()
            persistCooldowns()
        } catch {
            AppLogger.logError(error, context: "sendActionableNotification", logger: AppLogger.notifications)
        }
    }

    /// Send a volume suggestion notification
    func sendVolumeSuggestion(
        currentLevel: Double,
        currentDosePercent: Double,
        targetAdditionalTime: TimeInterval = 60 * 60, // 1 hour default
        doseModel: DoseModel
    ) async {
        guard isAuthorized else { return }

        let calculator = DoseCalculator(model: doseModel)

        // Calculate what level would give them the target additional time
        let suggestedLevel = calculator.safeLevelForRemainingTime(
            currentDosePercent: currentDosePercent,
            remainingListeningTime: targetAdditionalTime
        )

        // Only suggest if the reduction is meaningful (at least 3 dB)
        guard currentLevel - suggestedLevel >= 3 else { return }

        let content = ActionableNotificationBuilder.buildVolumeSuggestionNotification(
            currentLevel: currentLevel,
            suggestedLevel: suggestedLevel,
            additionalTime: targetAdditionalTime
        )

        let request = UNNotificationRequest(
            identifier: "volume-suggestion-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            AppLogger.logError(error, context: "sendVolumeSuggestion", logger: AppLogger.notifications)
        }
    }
    
    // MARK: - Exposure Event Notifications
    
    /// Send notification for a loud exposure event
    func sendExposureEventNotification(level: Double, duration: TimeInterval) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Loud Exposure Detected"
        content.body = "Your headphones were at \(Int(level)) dB for \(DoseCalculator.formatDuration(duration)). Consider taking a break."
        content.sound = .default
        content.categoryIdentifier = "EXPOSURE_EVENT"
        content.threadIdentifier = "exposure-events"
        
        let request = UNNotificationRequest(
            identifier: "exposure-event-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
        } catch {
            AppLogger.logError(error, context: "sendExposureEventNotification", logger: AppLogger.notifications)
        }
    }

    // MARK: - Break Reminders

    func sendBreakReminder(
        sessionMinutes: Int,
        breakMinutes: Int,
        cooldownSeconds: TimeInterval
    ) async {
        guard isAuthorized else { return }

        let cooldownKey = AppConfig.NotificationCooldownKey.breakReminder
        if let lastNotification = notificationCooldowns[cooldownKey],
           Date().timeIntervalSince(lastNotification) < cooldownSeconds {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Time for a Listening Break"
        content.body = "You've been listening for \(sessionMinutes) minutes. A \(breakMinutes)-minute break can help protect your hearing."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.breakReminder.rawValue
        content.threadIdentifier = "break-reminders"

        let request = UNNotificationRequest(
            identifier: "break-reminder-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            notificationCooldowns[cooldownKey] = Date()
            persistCooldowns()
        } catch {
            AppLogger.logError(error, context: "sendBreakReminder", logger: AppLogger.notifications)
        }
    }
    
    // MARK: - Daily Summary
    
    /// Schedule a daily summary notification
    func scheduleDailySummary(at hour: Int, minute: Int) async {
        guard isAuthorized else { return }
        
        // Remove existing daily summary
        center.removePendingNotificationRequests(withIdentifiers: ["daily-summary"])
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Hearing Summary"
        content.body = "Tap to see how your listening habits affected your hearing today."
        content.sound = nil
        content.categoryIdentifier = "DAILY_SUMMARY"
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-summary",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
        } catch {
            AppLogger.logError(error, context: "scheduleDailySummary", logger: AppLogger.notifications)
        }
    }
    
    func cancelDailySummary() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-summary"])
    }

    
    // MARK: - Notification Categories

    func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.viewDetails.rawValue,
            title: "View Details",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: "Dismiss",
            options: []
        )

        let showVolumeTipsAction = UNNotificationAction(
            identifier: NotificationAction.showVolumeTips.rawValue,
            title: "Volume Tips",
            options: [.foreground]
        )

        let startBreakTimerAction = UNNotificationAction(
            identifier: NotificationAction.startBreakTimer.rawValue,
            title: "Start Break Timer",
            options: [.foreground]
        )

        let viewDigestAction = UNNotificationAction(
            identifier: NotificationAction.viewDigest.rawValue,
            title: "View Digest",
            options: [.foreground]
        )

        // Dose threshold category
        let doseCategory = UNNotificationCategory(
            identifier: NotificationCategory.doseThreshold.rawValue,
            actions: [viewAction, showVolumeTipsAction, dismissAction],
            intentIdentifiers: []
        )

        // Exposure event category
        let eventCategory = UNNotificationCategory(
            identifier: NotificationCategory.exposureEvent.rawValue,
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        // Daily summary category
        let summaryCategory = UNNotificationCategory(
            identifier: NotificationCategory.dailySummary.rawValue,
            actions: [viewAction],
            intentIdentifiers: []
        )

        // Remaining time category with actionable options
        let remainingTimeCategory = UNNotificationCategory(
            identifier: NotificationCategory.remainingTime.rawValue,
            actions: [showVolumeTipsAction, startBreakTimerAction, dismissAction],
            intentIdentifiers: []
        )

        // Volume suggestion category
        let volumeSuggestionCategory = UNNotificationCategory(
            identifier: NotificationCategory.volumeSuggestion.rawValue,
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        // Context-aware category
        let contextAwareCategory = UNNotificationCategory(
            identifier: NotificationCategory.contextAware.rawValue,
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        // Weekly digest category
        let weeklyDigestCategory = UNNotificationCategory(
            identifier: NotificationCategory.weeklyDigest.rawValue,
            actions: [viewDigestAction, dismissAction],
            intentIdentifiers: []
        )

        // Break reminder category
        let breakReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.breakReminder.rawValue,
            actions: [startBreakTimerAction, dismissAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            doseCategory,
            eventCategory,
            summaryCategory,
            remainingTimeCategory,
            volumeSuggestionCategory,
            contextAwareCategory,
            weeklyDigestCategory,
            breakReminderCategory
        ])
    }
    
    // MARK: - Clear Notifications
    
    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
    }
    
    func clearPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    func resetCooldowns() {
        notificationCooldowns.removeAll()
        UserDefaults.standard.removeObject(forKey: cooldownStorageKey)
    }

    // MARK: - Agent Notifications

    func sendAgentNotification(title: String, body: String, threadId: String = "agent-alerts") async {
        await checkAuthorizationStatus()
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = threadId

        let request = UNNotificationRequest(
            identifier: "agent-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            AppLogger.logError(error, context: "sendAgentNotification", logger: AppLogger.notifications)
        }
    }

    // MARK: - Foreground Presentation

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
