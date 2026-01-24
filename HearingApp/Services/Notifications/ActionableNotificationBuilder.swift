import Foundation
import UserNotifications

/// Builds context-aware, actionable notifications with remaining time and volume suggestions
struct ActionableNotificationBuilder {

    // MARK: - Time of Day Context

    enum TimeContext: String {
        case morning
        case afternoon
        case evening
        case night

        static var current: TimeContext {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:
                return .morning
            case 12..<17:
                return .afternoon
            case 17..<21:
                return .evening
            default:
                return .night
            }
        }

        var greeting: String {
            switch self {
            case .morning:
                return "Good morning"
            case .afternoon:
                return "Good afternoon"
            case .evening:
                return "Good evening"
            case .night:
                return "Late night listening"
            }
        }

        var suggestion: String {
            switch self {
            case .morning:
                return "Start your day with mindful listening levels."
            case .afternoon:
                return "Take a listening break to rest your ears."
            case .evening:
                return "Wind down with lower volumes as your day ends."
            case .night:
                return "Consider giving your ears a rest before sleep."
            }
        }
    }

    // MARK: - Notification Content Builders

    /// Builds a notification showing remaining safe listening time
    static func buildRemainingTimeNotification(
        dosePercent: Double,
        remainingTime: TimeInterval,
        currentLevel: Double?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let timeContext = TimeContext.current

        let formattedTime = DoseCalculator.formatDuration(remainingTime)

        if remainingTime <= 0 {
            content.title = "Daily Limit Reached"
            content.body = "You've used your full daily allowance. \(timeContext.suggestion)"
        } else if remainingTime <= 30 * 60 { // 30 minutes or less
            content.title = "Running Low on Safe Time"
            if let level = currentLevel {
                content.body = "Only \(formattedTime) left at \(Int(level)) dB. Consider lowering your volume."
            } else {
                content.body = "Only \(formattedTime) of safe listening time remaining today."
            }
        } else {
            content.title = "\(Int(dosePercent))% of Daily Limit Used"
            if let level = currentLevel {
                content.body = "You have \(formattedTime) left at your current \(Int(level)) dB level."
            } else {
                content.body = "You have approximately \(formattedTime) of safe listening time remaining."
            }
        }

        content.sound = remainingTime <= 30 * 60 ? .default : nil
        content.categoryIdentifier = NotificationCategory.remainingTime.rawValue
        content.threadIdentifier = "dose-alerts"
        content.userInfo = [
            "dosePercent": dosePercent,
            "remainingSeconds": remainingTime,
            "timeContext": timeContext.rawValue
        ]

        return content
    }

    /// Builds a notification with volume lowering suggestion
    static func buildVolumeSuggestionNotification(
        currentLevel: Double,
        suggestedLevel: Double,
        additionalTime: TimeInterval
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        let formattedTime = DoseCalculator.formatDuration(additionalTime)
        let levelDrop = Int(currentLevel - suggestedLevel)

        content.title = "Volume Tip"
        content.body = "Lower to ~\(Int(suggestedLevel)) dB to gain \(formattedTime) more listening time. That's just \(levelDrop) dB quieter!"

        content.sound = nil // Silent notification
        content.categoryIdentifier = NotificationCategory.volumeSuggestion.rawValue
        content.threadIdentifier = "volume-tips"
        content.userInfo = [
            "currentLevel": currentLevel,
            "suggestedLevel": suggestedLevel,
            "additionalSeconds": additionalTime
        ]

        return content
    }

    /// Builds a context-aware notification based on time of day
    static func buildContextAwareNotification(
        dosePercent: Double,
        remainingTime: TimeInterval
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let timeContext = TimeContext.current

        content.title = timeContext.greeting

        let formattedTime = DoseCalculator.formatDuration(remainingTime)

        switch timeContext {
        case .morning:
            if dosePercent < 20 {
                content.body = "Fresh start! You have \(formattedTime) of safe listening time today."
            } else {
                content.body = "You've already used \(Int(dosePercent))% of your daily allowance. \(formattedTime) remaining."
            }
        case .afternoon:
            if dosePercent >= 50 {
                content.body = "Halfway through the day at \(Int(dosePercent))%. Consider a listening break."
            } else {
                content.body = "Doing great! \(formattedTime) of safe listening time still available."
            }
        case .evening:
            if dosePercent >= 80 {
                content.body = "Evening check-in: You're at \(Int(dosePercent))%. Only \(formattedTime) remaining."
            } else {
                content.body = "Wrapping up the day with \(formattedTime) still available."
            }
        case .night:
            content.body = "Late listening at \(Int(dosePercent))%. \(timeContext.suggestion)"
        }

        content.sound = nil
        content.categoryIdentifier = NotificationCategory.contextAware.rawValue
        content.threadIdentifier = "daily-tips"
        content.userInfo = [
            "dosePercent": dosePercent,
            "remainingSeconds": remainingTime,
            "timeContext": timeContext.rawValue
        ]

        return content
    }

    /// Builds enhanced threshold notification with remaining time info
    static func buildEnhancedThresholdNotification(
        threshold: Int,
        dosePercent: Double,
        remainingTime: TimeInterval,
        currentLevel: Double?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let formattedTime = DoseCalculator.formatDuration(remainingTime)

        switch threshold {
        case 100:
            content.title = "Daily Limit Reached"
            content.body = "You've used 100% of your daily sound allowance. Give your ears a break to protect your hearing."
            content.sound = .default
        case 80:
            content.title = "80% - Approaching Limit"
            if let level = currentLevel {
                content.body = "Only \(formattedTime) left at \(Int(level)) dB. Tap for volume tips."
            } else {
                content.body = "You have about \(formattedTime) of safe listening remaining. Consider lowering your volume."
            }
            content.sound = .default
        case 50:
            content.title = "Halfway There"
            content.body = "50% used. You have \(formattedTime) of safe listening time remaining today."
            content.sound = nil
        default:
            content.title = "\(threshold)% Reached"
            content.body = "You've used \(threshold)% of your daily allowance."
            content.sound = nil
        }

        content.categoryIdentifier = NotificationCategory.doseThreshold.rawValue
        content.threadIdentifier = "dose-alerts"
        content.userInfo = [
            "threshold": threshold,
            "dosePercent": dosePercent,
            "remainingSeconds": remainingTime
        ]

        return content
    }
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
}

// MARK: - Notification Actions

enum NotificationAction: String {
    case viewDetails = "VIEW_ACTION"
    case dismiss = "DISMISS_ACTION"
    case showVolumeTips = "SHOW_VOLUME_TIPS"
    case startBreakTimer = "START_BREAK_TIMER"
    case viewDigest = "VIEW_DIGEST"
}
