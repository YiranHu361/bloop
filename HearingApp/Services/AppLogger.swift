import Foundation
import os.log

/// Centralized logging using OSLog for performance and privacy.
/// Only logs in debug builds when verbose logging is enabled.
enum AppLogger {
    
    // MARK: - Subsystems
    
    private static let subsystem = "com.bloopapp.app"
    
    static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    static let general = Logger(subsystem: subsystem, category: "General")
    
    // MARK: - Convenience Logging
    
    /// Log debug message (only in debug builds with verbose logging enabled)
    static func debug(_ message: String, category: Logger = general) {
        #if DEBUG
        if FeatureFlags.verboseLoggingEnabled {
            category.debug("\(message, privacy: .public)")
        }
        #endif
    }
    
    /// Log info message (only in debug builds)
    static func info(_ message: String, category: Logger = general) {
        #if DEBUG
        category.info("\(message, privacy: .public)")
        #endif
    }
    
    /// Log warning (always, but privacy-safe)
    static func warning(_ message: String, category: Logger = general) {
        category.warning("\(message, privacy: .public)")
    }
    
    /// Log error (always, but privacy-safe)
    static func error(_ message: String, category: Logger = general) {
        category.error("\(message, privacy: .public)")
    }
    
    // MARK: - HealthKit Specific
    
    static func logSyncResult(inserted: Int, category: String = "samples") {
        #if DEBUG
        if FeatureFlags.verboseLoggingEnabled && inserted > 0 {
            healthKit.debug("Inserted \(inserted) new \(category, privacy: .public)")
        }
        #endif
    }
    
    static func logLiveUpdate(sampleCount: Int) {
        #if DEBUG
        if FeatureFlags.verboseLoggingEnabled {
            healthKit.debug("Live update: \(sampleCount) samples received")
        }
        #endif
    }
}
