import Foundation
import os.log

/// Centralized logging utility using OSLog for production diagnostics
enum AppLogger {
    // MARK: - Log Categories

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.bloopapp.app"

    static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let ai = Logger(subsystem: subsystem, category: "AI")
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    static let general = Logger(subsystem: subsystem, category: "General")

    // MARK: - Convenience Methods

    /// Log an error with context
    static func logError(_ error: Error, context: String, logger: Logger = general) {
        logger.error("[\(context)] \(error.localizedDescription, privacy: .public)")
    }

    /// Log a recoverable warning
    static func logWarning(_ message: String, context: String, logger: Logger = general) {
        logger.warning("[\(context)] \(message, privacy: .public)")
    }

    /// Log debug info (only in DEBUG builds)
    static func logDebug(_ message: String, context: String, logger: Logger = general) {
        #if DEBUG
        logger.debug("[\(context)] \(message, privacy: .public)")
        #endif
    }

    /// Log important info events
    static func logInfo(_ message: String, context: String, logger: Logger = general) {
        logger.info("[\(context)] \(message, privacy: .public)")
    }
}

// MARK: - Error Classification

/// Protocol for classifying errors as recoverable or fatal
protocol ClassifiableError: Error {
    var isRecoverable: Bool { get }
    var userMessage: String { get }
}

extension HealthKitError: ClassifiableError {
    var isRecoverable: Bool {
        switch self {
        case .notAvailable, .typesNotAvailable, .authorizationDenied:
            return false
        case .queryFailed:
            return true // Network/transient issues can be retried
        }
    }

    var userMessage: String {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
        case .typesNotAvailable:
            return "Required health data types are not available."
        case .authorizationDenied:
            return "Please enable HealthKit access in Settings to track your listening."
        case .queryFailed:
            return "Unable to fetch health data. Please try again."
        }
    }
}
