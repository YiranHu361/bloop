import WidgetKit
import SwiftUI
import ActivityKit

@main
struct BloopWidgetBundle: WidgetBundle {
    var body: some Widget {
        BloopWidget()
        BloopWidgetLockScreen()
        BloopLiveActivityWidget()
    }
}

// MARK: - Main Widget

struct BloopWidget: Widget {
    let kind: String = "BloopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoseTimelineProvider()) { entry in
            DoseRingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sound Exposure")
        .description("Track your child's daily sound exposure at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen Widget

@available(iOSApplicationExtension 16.0, *)
struct BloopWidgetLockScreen: Widget {
    let kind: String = "BloopWidgetLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoseTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Exposure Gauge")
        .description("Quick view of daily sound exposure on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview("Small Widget", as: .systemSmall) {
    BloopWidget()
} timeline: {
    DoseEntry(date: .now, dosePercent: 45, remainingTime: 4 * 3600, listeningTime: 45 * 60, status: .safe)
    DoseEntry(date: .now, dosePercent: 75, remainingTime: 1.5 * 3600, listeningTime: 2.5 * 3600, status: .moderate)
    DoseEntry(date: .now, dosePercent: 110, remainingTime: 0, listeningTime: 4.25 * 3600, status: .dangerous)
}

#Preview("Medium Widget", as: .systemMedium) {
    BloopWidget()
} timeline: {
    DoseEntry(date: .now, dosePercent: 65, remainingTime: 2.5 * 3600, listeningTime: 1.75 * 3600, status: .moderate)
}
