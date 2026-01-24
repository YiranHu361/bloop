import SwiftUI
import WidgetKit

// MARK: - Main Widget Views

struct DoseRingWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DoseEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: DoseEntry

    var body: some View {
        VStack(spacing: 8) {
            // Mini dose ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(entry.dosePercent / 100.0, 1.0))
                    .stroke(
                        entry.status.color,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(entry.dosePercent))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 80, height: 80)

            // Status
            Text(entry.status.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(entry.status.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: DoseEntry

    var body: some View {
        // A bit more breathing room between ring and text column
        HStack(spacing: 28) {
            // Dose ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: min(entry.dosePercent / 100.0, 1.0))
                    .stroke(
                        entry.status.color,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(entry.dosePercent))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("dose")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // Stats
            VStack(alignment: .leading, spacing: 12) {
                // Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.status.color)
                        .frame(width: 8, height: 8)

                    Text(entry.status.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }

                // Remaining time
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safe time left")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(formatDuration(entry.remainingTime))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(entry.remainingTime <= 30 * 60 ? Color(hex: "FF3B30") : .primary)
                }

                // Listening time today (minimal but useful)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Listened today")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(formatDuration(entry.listeningTime))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Last updated
                Text("Updated \(entry.date.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 2)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if seconds <= 0 {
            return "None"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Lock Screen Widgets

@available(iOSApplicationExtension 16.0, *)
struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DoseEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularAccessoryView(entry: entry)
        case .accessoryRectangular:
            RectangularAccessoryView(entry: entry)
        default:
            CircularAccessoryView(entry: entry)
        }
    }
}

@available(iOSApplicationExtension 16.0, *)
struct CircularAccessoryView: View {
    let entry: DoseEntry

    var body: some View {
        Gauge(value: min(entry.dosePercent / 100.0, 1.0)) {
            Image(systemName: "ear.badge.waveform")
        } currentValueLabel: {
            Text("\(Int(entry.dosePercent))")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(entry.status.color)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct RectangularAccessoryView: View {
    let entry: DoseEntry

    var body: some View {
        HStack(spacing: 8) {
            // Mini gauge
            Gauge(value: min(entry.dosePercent / 100.0, 1.0)) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(entry.status.color)
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Dose: \(Int(entry.dosePercent))%")
                    .font(.system(size: 12, weight: .semibold))

                Text(formatRemainingTime(entry.remainingTime))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if seconds <= 0 {
            return "Limit reached"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}

// MARK: - Previews

#Preview("Small") {
    SmallWidgetView(entry: DoseEntry(
        date: .now,
        dosePercent: 65,
        remainingTime: 2 * 3600,
        status: .moderate
    ))
    .previewContext(WidgetPreviewContext(family: .systemSmall))
}

#Preview("Medium") {
    MediumWidgetView(entry: DoseEntry(
        date: .now,
        dosePercent: 45,
        remainingTime: 4 * 3600,
        status: .safe
    ))
    .previewContext(WidgetPreviewContext(family: .systemMedium))
}
