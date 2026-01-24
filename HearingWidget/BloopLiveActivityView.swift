import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Live Activity Attributes (must match main app)

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
            
            var progressBarColor: Color {
                switch self {
                case .safe: return Color(red: 0.3, green: 0.85, blue: 0.5)
                case .caution: return Color(red: 1.0, green: 0.8, blue: 0.3)
                case .warning: return Color(red: 1.0, green: 0.6, blue: 0.3)
                case .danger: return Color(red: 1.0, green: 0.35, blue: 0.35)
                }
            }
        }
    }
    
    var startTime: Date
}

// MARK: - Live Activity Widget

struct BloopLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BloopExposureAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(state: context.state, startTime: context.attributes.startTime)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(state: context.state)
                }
            } compactLeading: {
                // Compact leading (left pill)
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                // Compact trailing (right pill)
                CompactTrailingView(state: context.state)
            } minimal: {
                // Minimal (single circle when other activities present)
                MinimalView(state: context.state)
            }
            .widgetURL(URL(string: "bloop://session"))
            .keylineTint(context.state.status.color)
        }
    }
}

// MARK: - Lock Screen Live Activity View

@available(iOSApplicationExtension 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BloopExposureAttributes>
    
    private var state: BloopExposureAttributes.ContentState { context.state }
    private var remainingPercent: Int { state.remainingPercent }
    private var usedPercent: Double { state.progressTowardLimit }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                // App branding
                HStack(spacing: 6) {
                    Image(systemName: "ear.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(state.status.color)
                    
                    Text("bloop.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Live indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(state.status.color)
                        .frame(width: 6, height: 6)
                    
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(state.status.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(state.status.color.opacity(0.2))
                )
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Status message
                Text(state.message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.15))
                        
                        // Filled portion (dose used)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        state.status.progressBarColor.opacity(0.8),
                                        state.status.progressBarColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * usedPercent)
                    }
                }
                .frame(height: 12)
                
                // Bottom stats row
                HStack {
                    // Remaining percentage
                    HStack(spacing: 4) {
                        Image(systemName: state.status.icon)
                            .font(.system(size: 12))
                            .foregroundColor(state.status.color)
                        
                        Text("\(remainingPercent)% left today")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Session duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Session: \(sessionDuration)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.18),
                            Color(red: 0.08, green: 0.10, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .activityBackgroundTint(Color.black.opacity(0.8))
    }
    
    private var sessionDuration: String {
        let elapsed = Date().timeIntervalSince(context.attributes.startTime)
        let minutes = Int(elapsed / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(max(1, minutes))m"
        }
    }
}

// MARK: - Dynamic Island Views

@available(iOSApplicationExtension 16.1, *)
struct CompactLeadingView: View {
    let state: BloopExposureAttributes.ContentState
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "ear.fill")
                .font(.system(size: 12))
                .foregroundColor(state.status.color)
            
            Text("\(state.remainingPercent)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct CompactTrailingView: View {
    let state: BloopExposureAttributes.ContentState
    
    var body: some View {
        // Mini progress indicator
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: state.progressTowardLimit)
                .stroke(state.status.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

@available(iOSApplicationExtension 16.1, *)
struct MinimalView: View {
    let state: BloopExposureAttributes.ContentState
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: state.progressTowardLimit)
                .stroke(state.status.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Image(systemName: "ear.fill")
                .font(.system(size: 10))
                .foregroundColor(state.status.color)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct ExpandedLeadingView: View {
    let state: BloopExposureAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "ear.fill")
                    .font(.system(size: 14))
                    .foregroundColor(state.status.color)
                
                Text("bloop.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            
            Text("\(state.remainingPercent)% left")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct ExpandedTrailingView: View {
    let state: BloopExposureAttributes.ContentState
    
    var body: some View {
        // Circular progress showing used percentage
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: state.progressTowardLimit)
                .stroke(
                    state.status.progressBarColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 0) {
                Text("\(state.currentPercent)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: 48, height: 48)
    }
}

@available(iOSApplicationExtension 16.1, *)
struct ExpandedCenterView: View {
    let state: BloopExposureAttributes.ContentState
    
    var body: some View {
        EmptyView()
    }
}

@available(iOSApplicationExtension 16.1, *)
struct ExpandedBottomView: View {
    let state: BloopExposureAttributes.ContentState
    let startTime: Date
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar using custom limit
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(state.status.progressBarColor)
                        .frame(width: geo.size.width * state.progressTowardLimit)
                }
            }
            .frame(height: 8)
            
            // Message
            HStack {
                Text(state.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                // Session time
                Text("Session: \(sessionDuration)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private var sessionDuration: String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed / 60)
        if minutes < 1 {
            return "< 1m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }
}

// MARK: - Note on Previews
// Live Activities cannot be previewed in Xcode Previews.
// Test Live Activities on a physical device or simulator by running the app.
