import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes

struct BloopExposureAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentPercent: Int           // Daily dose used (0-100+)
        var dailyLimitPercent: Int        // User's configured daily limit (default 100)
        var currentDB: Int
        var status: ExposureStatusType
        var message: String
        var remainingMinutes: Int?
        var isBreakTime: Bool
        
        /// Remaining budget percentage (limit - used)
        var remainingPercent: Int {
            max(0, dailyLimitPercent - currentPercent)
        }
        
        /// Progress toward limit (0.0 to 1.0+)
        var progressTowardLimit: Double {
            guard dailyLimitPercent > 0 else { return 0 }
            return min(Double(currentPercent) / Double(dailyLimitPercent), 1.5)
        }
        
        enum ExposureStatusType: String, Codable, Hashable {
            case safe
            case caution
            case warning
            case danger
            
            var color: Color {
                switch self {
                case .safe: return .green
                case .caution: return .yellow
                case .warning: return .orange
                case .danger: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .safe: return "checkmark.circle.fill"
                case .caution: return "exclamationmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .danger: return "xmark.octagon.fill"
                }
            }
            
            var kidFriendlyMessage: String {
                switch self {
                case .safe: return "Your ears are happy! 👂"
                case .caution: return "Getting a bit loud!"
                case .warning: return "Time to turn it down!"
                case .danger: return "Your ears need a break!"
                }
            }
        }
    }
    
    // Fixed non-changing properties
    var startTime: Date
}

// MARK: - Live Activity Service

@MainActor
final class BloopLiveActivity: ObservableObject {
    static let shared = BloopLiveActivity()

    @Published private(set) var currentActivity: Activity<BloopExposureAttributes>?
    @Published private(set) var isRunning: Bool = false

    /// Cached daily limit to use when updating
    private var cachedDailyLimit: Int = 100

    private init() {
        // Sync with any existing activity on init (handles app restart scenarios)
        syncWithExistingActivity()
    }

    /// Syncs the currentActivity reference with any existing Live Activity
    /// This handles cases where the app restarts but a Live Activity is still running
    private func syncWithExistingActivity() {
        let existingActivities = Activity<BloopExposureAttributes>.activities
        if let existing = existingActivities.first {
            currentActivity = existing
            isRunning = true
            AppLogger.logInfo("Synced with existing Live Activity: \(existing.id)", context: "syncWithExistingActivity", logger: AppLogger.notifications)
        }
    }

    /// Ends ALL existing Live Activities to prevent duplicates
    /// This handles orphaned activities from app crashes, restarts, or state loss
    private func endAllExistingActivities() async {
        let existingActivities = Activity<BloopExposureAttributes>.activities

        guard !existingActivities.isEmpty else { return }

        AppLogger.logInfo("Ending \(existingActivities.count) existing Live Activities", context: "endAllExistingActivities", logger: AppLogger.notifications)

        for activity in existingActivities {
            let finalState = BloopExposureAttributes.ContentState(
                currentPercent: 0,
                dailyLimitPercent: cachedDailyLimit,
                currentDB: 0,
                status: .safe,
                message: "Session ended",
                remainingMinutes: nil,
                isBreakTime: false
            )

            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        currentActivity = nil
        isRunning = false
    }
    
    // MARK: - Start/Update/End
    
    func startExposureTracking(
        currentPercent: Int,
        currentDB: Int,
        status: ExposureStatus,
        dailyLimitPercent: Int = 100
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.logWarning("Live Activities not enabled by user", context: "startExposureTracking", logger: AppLogger.notifications)
            return
        }

        // End ALL existing activities first (prevents duplicates from orphaned activities)
        await endAllExistingActivities()
        
        // Cache the limit
        cachedDailyLimit = dailyLimitPercent
        
        let attributes = BloopExposureAttributes(startTime: Date())
        let state = BloopExposureAttributes.ContentState(
            currentPercent: currentPercent,
            dailyLimitPercent: dailyLimitPercent,
            currentDB: currentDB,
            status: mapStatus(status),
            message: status.kidFriendlyMessage,
            remainingMinutes: nil,
            isBreakTime: false
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            isRunning = true
            AppLogger.logInfo("Live Activity started: \(activity.id)", context: "startExposureTracking", logger: AppLogger.notifications)
        } catch {
            AppLogger.logError(error, context: "startLiveActivity", logger: AppLogger.notifications)
        }
    }
    
    func updateExposure(
        currentPercent: Int,
        currentDB: Int,
        status: ExposureStatus,
        dailyLimitPercent: Int? = nil,
        remainingMinutes: Int? = nil,
        isBreakTime: Bool = false
    ) async {
        // Update cached limit if provided
        if let limit = dailyLimitPercent {
            cachedDailyLimit = limit
        }
        
        guard let activity = currentActivity else {
            // Start new activity if none exists
            await startExposureTracking(
                currentPercent: currentPercent,
                currentDB: currentDB,
                status: status,
                dailyLimitPercent: dailyLimitPercent ?? cachedDailyLimit
            )
            return
        }
        
        let state = BloopExposureAttributes.ContentState(
            currentPercent: currentPercent,
            dailyLimitPercent: dailyLimitPercent ?? cachedDailyLimit,
            currentDB: currentDB,
            status: mapStatus(status),
            message: isBreakTime ? "Time for a break!" : status.kidFriendlyMessage,
            remainingMinutes: remainingMinutes,
            isBreakTime: isBreakTime
        )
        
        await activity.update(
            ActivityContent(state: state, staleDate: nil)
        )
    }
    
    func showBreakReminder(breakDurationMinutes: Int) async {
        guard let activity = currentActivity else { return }
        
        let state = BloopExposureAttributes.ContentState(
            currentPercent: 0,
            dailyLimitPercent: cachedDailyLimit,
            currentDB: 0,
            status: .caution,
            message: "Take a \(breakDurationMinutes) minute break!",
            remainingMinutes: breakDurationMinutes,
            isBreakTime: true
        )
        
        await activity.update(
            ActivityContent(state: state, staleDate: nil)
        )
    }
    
    func endActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = BloopExposureAttributes.ContentState(
            currentPercent: 0,
            dailyLimitPercent: cachedDailyLimit,
            currentDB: 0,
            status: .safe,
            message: "Listening session ended",
            remainingMinutes: nil,
            isBreakTime: false
        )
        
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        
        currentActivity = nil
        isRunning = false
    }
    
    // MARK: - Helpers
    
    private func mapStatus(_ status: ExposureStatus) -> BloopExposureAttributes.ContentState.ExposureStatusType {
        switch status {
        case .safe: return .safe
        case .moderate: return .caution
        case .high: return .warning
        case .dangerous: return .danger
        }
    }
}

// MARK: - Kid-Friendly Messages Extension

extension ExposureStatus {
    var kidFriendlyMessage: String {
        switch self {
        case .safe:
            return ["Your ears are happy!", "Great listening!", "Safe and sound!"].randomElement() ?? "Your ears are happy!"
        case .moderate:
            return ["Getting a bit loud", "Maybe turn it down?", "Ears say: careful!"].randomElement() ?? "Getting a bit loud"
        case .high:
            return ["Too loud!", "Time to turn it down", "Your ears need help!"].randomElement() ?? "Too loud!"
        case .dangerous:
            return ["Way too loud!", "Take a break now!", "Ears need rest!"].randomElement() ?? "Take a break now!"
        }
    }
}
