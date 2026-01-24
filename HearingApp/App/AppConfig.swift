import Foundation

/// App-wide configuration and constants
struct AppConfig {
    
    // MARK: - App Information
    static let appName = "Hearing App"
    static let appVersion = "1.0.0"
    static let bundleIdentifier = "com.example.hearingapp"
    
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
    }
    
    // MARK: - Debug Configuration
    #if DEBUG
    static let enableDebugLogging = true
    static let enableSampleDataGeneration = true
    #else
    static let enableDebugLogging = false
    static let enableSampleDataGeneration = false
    #endif
}