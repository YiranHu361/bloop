import WidgetKit
import SwiftUI

@main
struct HearingWidgetBundle: WidgetBundle {
    var body: some Widget {
        HearingWidget()

        #if os(iOS)
        if #available(iOSApplicationExtension 16.0, *) {
            HearingWidgetLockScreen()
        }
        #endif
    }
}

// MARK: - Main Widget

struct HearingWidget: Widget {
    let kind: String = "HearingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoseTimelineProvider()) { entry in
            DoseRingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Dose")
        .description("Track your daily sound exposure at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen Widget

@available(iOSApplicationExtension 16.0, *)
struct HearingWidgetLockScreen: Widget {
    let kind: String = "HearingWidgetLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoseTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Dose Gauge")
        .description("Quick view of your daily dose on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview("Small Widget", as: .systemSmall) {
    HearingWidget()
} timeline: {
    DoseEntry(date: .now, dosePercent: 45, remainingTime: 4 * 3600, status: .safe)
    DoseEntry(date: .now, dosePercent: 75, remainingTime: 1.5 * 3600, status: .moderate)
    DoseEntry(date: .now, dosePercent: 110, remainingTime: 0, status: .dangerous)
}

#Preview("Medium Widget", as: .systemMedium) {
    HearingWidget()
} timeline: {
    DoseEntry(date: .now, dosePercent: 65, remainingTime: 2.5 * 3600, status: .moderate)
}
