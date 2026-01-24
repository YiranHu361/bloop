import Foundation
import UserNotifications
import SwiftData
import UIKit

/// Enhanced notification service for bloop. with kid-friendly prominent alerts
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false
    @Published var criticalAlertsAuthorized: Bool = false
    
    private let center = UNUserNotificationCenter.current()
    private var notificationCooldowns: [Int: Date] = [:]
    private let cooldownInterval: TimeInterval = 1800 // 30 minutes between same threshold notifications
    
    // Kid-friendly message templates
    private let kidFriendlyMessages = KidFriendlyMessages()
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            // Request standard notifications + provisional for quiet delivery
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge, .provisional]
            )
            isAuthorized = granted
        } catch {
            print("Notification authorization error: \(error)")
            isAuthorized = false
        }
    }
    
    func requestCriticalAlerts() async {
        // Note: Critical alerts require special entitlement from Apple
        // For now, we'll use high-priority notifications
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert]
            )
            criticalAlertsAuthorized = granted
        } catch {
            print("Critical alerts authorization error: \(error)")
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        criticalAlertsAuthorized = settings.criticalAlertSetting == .enabled
    }
    
    // MARK: - Prominent Kid-Friendly Notifications
    
    /// Send a prominent threshold notification with kid-friendly messaging
    func sendProminentAlert(
        threshold: Int,
        dosePercent: Double,
        useKidFriendly: Bool = true,
        style: NotificationStyle = .prominent
    ) async {
        guard isAuthorized else { return }
        
        // Check cooldown
        if let lastNotification = notificationCooldowns[threshold],
           Date().timeIntervalSince(lastNotification) < cooldownInterval {
            return
        }
        
        let content = UNMutableNotificationContent()
        
        // Set content based on threshold and style
        switch threshold {
        case 100:
            if useKidFriendly {
                content.title = "🛑 Time for a Break!"
                content.body = kidFriendlyMessages.limitReached.randomElement()!
                content.subtitle = "Your ears have worked hard today"
            } else {
                content.title = "Daily Limit Reached"
                content.body = "100% of daily sound exposure used. Take a listening break."
                content.subtitle = "Hearing protection alert"
            }
            content.sound = prominentSound(for: style)
            content.interruptionLevel = .timeSensitive
            
        case 80:
            if useKidFriendly {
                content.title = "⚠️ Getting Loud!"
                content.body = kidFriendlyMessages.approaching.randomElement()!
                content.subtitle = "Almost at today's limit"
            } else {
                content.title = "80% - Approaching Limit"
                content.body = "Consider turning down the volume."
                content.subtitle = "Hearing protection warning"
            }
            content.sound = prominentSound(for: style)
            content.interruptionLevel = .timeSensitive
            
        case 60:
            if useKidFriendly {
                content.title = "👂 Heads Up!"
                content.body = kidFriendlyMessages.headsUp.randomElement()!
            } else {
                content.title = "60% - Heads Up"
                content.body = "Over halfway through today's safe listening time."
            }
            content.sound = style == .prominent ? .default : nil
            content.interruptionLevel = .active
            
        default:
            return
        }
        
        content.categoryIdentifier = NotificationCategory.doseThreshold.rawValue
        content.threadIdentifier = "bloop-alerts"
        content.relevanceScore = threshold >= 100 ? 1.0 : (threshold >= 80 ? 0.8 : 0.5)
        
        // Add banner image if available
        if let attachment = createBannerAttachment(for: threshold) {
            content.attachments = [attachment]
        }
        
        let request = UNNotificationRequest(
            identifier: "bloop-threshold-\(threshold)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
            notificationCooldowns[threshold] = Date()
            
            // Also update Live Activity if enabled
            await updateLiveActivityIfNeeded(percent: Int(dosePercent))
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
    
    // MARK: - Break Reminder Notifications
    
    func sendBreakReminder(
        afterMinutes: Int,
        breakDuration: Int,
        enforcement: BreakEnforcementLevel,
        useKidFriendly: Bool = true
    ) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        
        if useKidFriendly {
            content.title = "⏰ Break Time!"
            content.body = kidFriendlyMessages.breakTime.randomElement()!
            content.subtitle = "Your ears will thank you!"
        } else {
            content.title = "Time for a Listening Break"
            content.body = "You've been listening for \(afterMinutes) minutes. Take a \(breakDuration)-minute break."
        }
        
        switch enforcement {
        case .gentle:
            content.sound = nil
            content.interruptionLevel = .passive
        case .moderate:
            content.sound = .default
            content.interruptionLevel = .active
        case .strict:
            content.sound = prominentSound(for: .prominent)
            content.interruptionLevel = .timeSensitive
        case .off:
            return
        }
        
        content.categoryIdentifier = NotificationCategory.breakReminder.rawValue
        content.threadIdentifier = "bloop-breaks"
        
        let request = UNNotificationRequest(
            identifier: "bloop-break-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
            
            // Show break on Live Activity too
            await BloopLiveActivity.shared.showBreakReminder(breakDurationMinutes: breakDuration)
        } catch {
            print("Failed to send break reminder: \(error)")
        }
    }
    
    // MARK: - Instant Volume Alert
    
    func sendInstantVolumeAlert(currentDB: Int, threshold: Int, useKidFriendly: Bool = true) async {
        guard isAuthorized else { return }
        
        // Rate limit to prevent spam
        let volumeAlertKey = 2000
        if let lastAlert = notificationCooldowns[volumeAlertKey],
           Date().timeIntervalSince(lastAlert) < 60 { // 1 minute cooldown
            return
        }
        
        let content = UNMutableNotificationContent()
        
        if useKidFriendly {
            content.title = "🔊 Too Loud!"
            content.body = kidFriendlyMessages.tooLoud.randomElement()!
            content.subtitle = "Turn it down a little"
        } else {
            content.title = "Volume Alert: \(currentDB) dB"
            content.body = "Current volume exceeds \(threshold) dB safe threshold."
        }
        
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = NotificationCategory.volumeAlert.rawValue
        content.relevanceScore = 1.0
        
        let request = UNNotificationRequest(
            identifier: "bloop-volume-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
            notificationCooldowns[volumeAlertKey] = Date()
        } catch {
            print("Failed to send volume alert: \(error)")
        }
    }
    
    // MARK: - Quiet Hours Alert
    
    func sendQuietHoursAlert(useKidFriendly: Bool = true) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        
        if useKidFriendly {
            content.title = "🌙 It's Quiet Time"
            content.body = kidFriendlyMessages.quietHours.randomElement()!
        } else {
            content.title = "Quiet Hours Active"
            content.body = "Headphone use is not recommended during quiet hours."
        }
        
        content.sound = .default
        content.interruptionLevel = .active
        content.categoryIdentifier = NotificationCategory.quietHours.rawValue
        
        let request = UNNotificationRequest(
            identifier: "bloop-quiet-hours-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Failed to send quiet hours alert: \(error)")
        }
    }
    
    // MARK: - Weekly Report Notification
    
    func scheduleWeeklyReport(on weekday: Int, at hour: Int = 10) async {
        guard isAuthorized else { return }
        
        center.removePendingNotificationRequests(withIdentifiers: ["bloop-weekly-report"])
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Weekly Listening Report"
        content.body = "See how your child's ears did this week!"
        content.sound = nil
        content.categoryIdentifier = NotificationCategory.weeklyDigest.rawValue
        
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "bloop-weekly-report",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule weekly report: \(error)")
        }
    }
    
    // MARK: - Check and Notify (Main Entry Point)
    
    /// Main method called to check exposure and send appropriate notifications
    func checkAndNotify(
        dosePercent: Double,
        currentDB: Int? = nil,
        settings: UserSettings? = nil
    ) async {
        guard isAuthorized else { return }
        
        let useKidFriendly = settings?.kidFriendlyMessages ?? true
        let style = settings?.notificationStyleEnum ?? .prominent
        
        // Check each threshold
        if dosePercent >= 100 && (settings?.warningThreshold100Enabled ?? true) {
            await sendProminentAlert(threshold: 100, dosePercent: dosePercent, useKidFriendly: useKidFriendly, style: style)
        } else if dosePercent >= 80 && (settings?.warningThreshold80Enabled ?? true) {
            await sendProminentAlert(threshold: 80, dosePercent: dosePercent, useKidFriendly: useKidFriendly, style: style)
        } else if dosePercent >= 60 && (settings?.warningThreshold50Enabled ?? true) {
            await sendProminentAlert(threshold: 60, dosePercent: dosePercent, useKidFriendly: useKidFriendly, style: style)
        }
        
        // Check instant volume alert
        if let db = currentDB,
           settings?.instantVolumeAlerts ?? true,
           db >= (settings?.volumeAlertThresholdDB ?? 90) {
            await sendInstantVolumeAlert(currentDB: db, threshold: settings?.volumeAlertThresholdDB ?? 90, useKidFriendly: useKidFriendly)
        }
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
        
        let takeBreakAction = UNNotificationAction(
            identifier: NotificationAction.startBreakTimer.rawValue,
            title: "Start Break Timer",
            options: [.foreground]
        )
        
        let volumeTipsAction = UNNotificationAction(
            identifier: NotificationAction.showVolumeTips.rawValue,
            title: "Volume Tips",
            options: [.foreground]
        )
        
        // Dose threshold category
        let doseCategory = UNNotificationCategory(
            identifier: NotificationCategory.doseThreshold.rawValue,
            actions: [takeBreakAction, volumeTipsAction, dismissAction],
            intentIdentifiers: []
        )
        
        // Break reminder category
        let breakCategory = UNNotificationCategory(
            identifier: NotificationCategory.breakReminder.rawValue,
            actions: [takeBreakAction, dismissAction],
            intentIdentifiers: []
        )
        
        // Volume alert category
        let volumeCategory = UNNotificationCategory(
            identifier: NotificationCategory.volumeAlert.rawValue,
            actions: [volumeTipsAction, dismissAction],
            intentIdentifiers: []
        )
        
        // Quiet hours category
        let quietCategory = UNNotificationCategory(
            identifier: NotificationCategory.quietHours.rawValue,
            actions: [dismissAction],
            intentIdentifiers: []
        )
        
        // Weekly report category
        let weeklyCategory = UNNotificationCategory(
            identifier: NotificationCategory.weeklyDigest.rawValue,
            actions: [viewAction],
            intentIdentifiers: []
        )
        
        center.setNotificationCategories([
            doseCategory,
            breakCategory,
            volumeCategory,
            quietCategory,
            weeklyCategory
        ])
    }
    
    // MARK: - Live Activity Integration
    
    private func updateLiveActivityIfNeeded(percent: Int) async {
        // Update Live Activity if it's running
        if BloopLiveActivity.shared.isRunning {
            let status: ExposureStatus
            if percent >= 100 {
                status = .dangerous
            } else if percent >= 80 {
                status = .elevated
            } else if percent >= 60 {
                status = .moderate
            } else {
                status = .safe
            }
            
            await BloopLiveActivity.shared.updateExposure(
                currentPercent: percent,
                currentDB: 0, // Will be updated by caller if available
                status: status
            )
        }
    }
    
    // MARK: - Helpers
    
    private func prominentSound(for style: NotificationStyle) -> UNNotificationSound {
        switch style {
        case .prominent:
            return UNNotificationSound.defaultCritical
        case .standard:
            return UNNotificationSound.default
        case .minimal:
            return UNNotificationSound.default
        }
    }
    
    private func createBannerAttachment(for threshold: Int) -> UNNotificationAttachment? {
        // In a full implementation, this would create a custom banner image
        // For now, return nil
        return nil
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

// MARK: - Kid-Friendly Messages

struct KidFriendlyMessages {
    let headsUp = [
        "Your ears have been working hard! Maybe take a quick break?",
        "Halfway through your listening time! Still going strong 💪",
        "Your ears say: 'We're doing okay, but a break would be nice!'",
    ]
    
    let approaching = [
        "Whoa, getting close to the limit! Time to chill a bit? 😎",
        "Your ears are saying 'almost there!' Let's slow down.",
        "80% - Almost at today's limit! How about a little break?",
    ]
    
    let limitReached = [
        "Your ears worked super hard today! Time for a well-deserved rest 🎧➡️😴",
        "100%! Great listening session - now let's give those ears a break!",
        "Daily goal reached! Your ears need some quiet time now.",
    ]
    
    let breakTime = [
        "Hey! Your ears have been listening for a while. Quick break? ☕",
        "Break time! Even superheroes need to rest their ears 🦸",
        "Pause time! Let's give your ears a mini vacation 🏖️",
    ]
    
    let tooLoud = [
        "Whoa, that's LOUD! Turn it down a notch? Your ears will thank you!",
        "Volume alert! 🔊 Let's protect those awesome ears!",
        "Too loud! Quick, turn it down before your ears get grumpy!",
    ]
    
    let quietHours = [
        "It's quiet time! Your ears need their beauty sleep too 😴",
        "Shh! It's rest time for ears. Maybe save the music for tomorrow?",
        "Nighttime = ear rest time! Sweet dreams! 🌙",
    ]
}

// MARK: - Notification Categories

enum NotificationCategory: String {
    case doseThreshold = "DOSE_THRESHOLD"
    case exposureEvent = "EXPOSURE_EVENT"
    case dailySummary = "DAILY_SUMMARY"
    case remainingTime = "REMAINING_TIME"
    case volumeSuggestion = "VOLUME_SUGGESTION"
    case contextAware = "CONTEXT_AWARE"
    case weeklyDigest = "WEEKLY_DIGEST"
    case breakReminder = "BREAK_REMINDER"
    case volumeAlert = "VOLUME_ALERT"
    case quietHours = "QUIET_HOURS"
}

// MARK: - Notification Actions

enum NotificationAction: String {
    case viewDetails = "VIEW_DETAILS"
    case dismiss = "DISMISS"
    case showVolumeTips = "SHOW_VOLUME_TIPS"
    case startBreakTimer = "START_BREAK_TIMER"
    case viewDigest = "VIEW_DIGEST"
}
