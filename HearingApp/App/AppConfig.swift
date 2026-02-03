import Foundation

/// App-wide configuration and constants
struct AppConfig {
    
    // MARK: - App Information
    static let appName = "bloop."
    static let appVersion = "1.0.0"
    static let bundleIdentifier = "com.bloopapp.app"
    
    // MARK: - HealthKit Configuration
    static let healthKitSyncIntervalMinutes: Double = 15
    static let backgroundSyncEnabled = true
    static let maxDaysToSync = 30
    
    // MARK: - Notification Configuration  
    static let notificationCooldownHours: Double = 1
    static let enableBackgroundNotifications = true
    
    // MARK: - UI Configuration
    static let maxRetentionDays = 365
    static let defaultAnimationDuration: Double = 0.3
    
    // MARK: - Thresholds
    struct DoseThresholds {
        static let warning50 = 50.0
        static let warning80 = 80.0
        static let danger100 = 100.0

        // dB level thresholds
        static let safeMaxDB = 70.0
        static let cautionDB = 85.0
        static let dangerDB = 90.0
        static let extremeDB = 100.0
    }

    // MARK: - API Configuration
    struct API {
        static let geminiRequestTimeoutSeconds: TimeInterval = 30
        static let geminiMaxRetries = 3
        static let geminiBaseRetryDelaySeconds: TimeInterval = 1.0
        static let geminiMaxRequestsPerMinute = 15
        static let geminiRefreshIntervalSeconds: TimeInterval = 60
    }

    // MARK: - Agent Configuration
    struct Agent {
        static let evaluationCooldownSeconds: TimeInterval = 60
        static let interventionCooldownSeconds: TimeInterval = 600 // 10 minutes
        static let complianceWindowSeconds: TimeInterval = 1800 // 30 minutes
        static let breakDetectionThresholdSeconds: TimeInterval = 600 // 10 minutes
        static let sessionGapSeconds: TimeInterval = 300 // 5 minutes
        static let volumeDropThresholdDB: Double = 3
        static let recentSampleWindowSeconds: TimeInterval = 600 // 10 minutes
        static let dailyLimitMin = 70
        static let dailyLimitMax = 100
        static let volumeThresholdMinDB = 60
        static let volumeThresholdMaxDB = 95
        static let ignoreWindowSeconds: TimeInterval = 6 * 60 * 60 // 6 hours
        static let ignoreThreshold = 3
    }

    // MARK: - Notification Cooldown Keys
    struct NotificationCooldownKey {
        static let actionable = 1000
        static let breakReminder = 2001
    }

    // MARK: - Timeline Configuration
    struct Timeline {
        static let gapThresholdSeconds: TimeInterval = 600 // 10 minutes
        static let maxTimelinePoints = 144 // ~10 min resolution over 24 hours
        static let trendlinePoints = 48 // One point every 30 minutes
        static let trendlineWindowSeconds: TimeInterval = 3600 // 1 hour
        static let twentyFourHoursSeconds: TimeInterval = 86400
    }

    // MARK: - Sync Configuration
    struct Sync {
        static let cooldownSeconds: TimeInterval = 60
        static let debounceMilliseconds = 500
    }

    // MARK: - App Group
    // ⚠️ SYNC WARNING: This value MUST match WidgetConstants.appGroupIdentifier in HearingWidget/WidgetTimelineProvider.swift
    // If you change one, you MUST change the other, or widget/app communication will break!
    static let appGroupIdentifier = "group.com.bloopapp.shared"

    // MARK: - Debug Configuration
    #if DEBUG
    static let enableDebugLogging = true
    static let enableSampleDataGeneration = true
    #else
    static let enableDebugLogging = false
    static let enableSampleDataGeneration = false
    #endif
}