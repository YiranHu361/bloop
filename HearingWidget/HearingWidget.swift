import WidgetKit
import SwiftUI

@main
struct HearingWidgetBundle: WidgetBundle {
    var body: some Widget {
        HearingWidget()
    }
}

struct HearingWidget: Widget {
    let kind: String = "HearingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoseTimelineProvider()) { entry in
            DoseWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Dose")
        .description("Track your daily sound exposure at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DoseEntry: TimelineEntry {
    let date: Date
    let dosePercent: Double
    let remainingTime: TimeInterval
    let status: ExposureStatus
}

struct DoseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DoseEntry {
        DoseEntry(date: Date(), dosePercent: 45, remainingTime: 4 * 3600, status: .safe)
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) {
        let entry = DoseEntry(date: Date(), dosePercent: 45, remainingTime: 4 * 3600, status: .safe)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        let appGroupIdentifier = "group.com.hearingapp.shared"
        let defaults = UserDefaults(suiteName: appGroupIdentifier)

        let dosePercent = defaults?.double(forKey: "widget_dosePercent") ?? 0
        let remainingTime = defaults?.double(forKey: "widget_remainingTime") ?? 0
        let status = ExposureStatus.from(dosePercent: dosePercent)

        let entry = DoseEntry(
            date: Date(),
            dosePercent: dosePercent,
            remainingTime: remainingTime,
            status: status
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DoseWidgetView: View {
    let entry: DoseEntry

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(entry.dosePercent / 100, 1.0))
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(entry.dosePercent))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .frame(width: 60, height: 60)

            Text("Daily Dose")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(entry.status.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(statusColor)
        }
        .padding()
    }

    private var statusColor: Color {
        switch entry.status {
        case .safe: return .green
        case .moderate: return .orange
        case .high: return .orange
        case .dangerous: return .red
        }
    }
}

enum ExposureStatus: String {
    case safe, moderate, high, dangerous

    static func from(dosePercent: Double) -> ExposureStatus {
        switch dosePercent {
        case 0..<50: return .safe
        case 50..<80: return .moderate
        case 80..<100: return .high
        default: return .dangerous
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

#Preview("Small Widget", as: .systemSmall) {
    HearingWidget()
} timeline: {
    DoseEntry(date: .now, dosePercent: 45, remainingTime: 4 * 3600, status: .safe)
    DoseEntry(date: .now, dosePercent: 75, remainingTime: 1.5 * 3600, status: .moderate)
}
