import Foundation
import UserNotifications

/// Service for managing local notifications
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false
    
    private let center = UNUserNotificationCenter.current()
    private var notificationCooldowns: [Int: Date] = [:] // threshold -> last notification time
    private let cooldownInterval: TimeInterval = 3600 // 1 hour between same threshold notifications
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            print("Notification authorization error: \(error)")
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
        } catch {
            print("Failed to send notification: \(error)")
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
        let actionableCooldownKey = 1000 // Use a distinct key
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
        } catch {
            print("Failed to send actionable notification: \(error)")
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
            print("Failed to send volume suggestion: \(error)")
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
            print("Failed to send exposure event notification: \(error)")
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
            print("Failed to schedule daily summary: \(error)")
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

        center.setNotificationCategories([
            doseCategory,
            eventCategory,
            summaryCategory,
            remainingTimeCategory,
            volumeSuggestionCategory,
            contextAwareCategory,
            weeklyDigestCategory
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
    }
}
