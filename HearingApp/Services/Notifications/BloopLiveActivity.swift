import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes

struct BloopExposureAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentPercent: Int
        var currentDB: Int
        var status: ExposureStatusType
        var message: String
        var remainingMinutes: Int?
        var isBreakTime: Bool
        
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
    
    private init() {}
    
    // MARK: - Start/Update/End
    
    func startExposureTracking(
        currentPercent: Int,
        currentDB: Int,
        status: ExposureStatus
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("BloopLiveActivity: Activities not enabled")
            return
        }
        
        // End any existing activity first
        await endActivity()
        
        let attributes = BloopExposureAttributes(startTime: Date())
        let state = BloopExposureAttributes.ContentState(
            currentPercent: currentPercent,
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
            print("BloopLiveActivity: Started activity \(activity.id)")
        } catch {
            print("BloopLiveActivity: Failed to start - \(error)")
        }
    }
    
    func updateExposure(
        currentPercent: Int,
        currentDB: Int,
        status: ExposureStatus,
        remainingMinutes: Int? = nil,
        isBreakTime: Bool = false
    ) async {
        guard let activity = currentActivity else {
            // Start new activity if none exists
            await startExposureTracking(
                currentPercent: currentPercent,
                currentDB: currentDB,
                status: status
            )
            return
        }
        
        let state = BloopExposureAttributes.ContentState(
            currentPercent: currentPercent,
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
            return ["Your ears are happy!", "Great listening!", "Safe and sound!"].randomElement()!
        case .moderate:
            return ["Getting a bit loud", "Maybe turn it down?", "Ears say: careful!"].randomElement()!
        case .high:
            return ["Too loud!", "Time to turn it down", "Your ears need help!"].randomElement()!
        case .dangerous:
            return ["Way too loud!", "Take a break now!", "Ears need rest!"].randomElement()!
        }
    }
}
