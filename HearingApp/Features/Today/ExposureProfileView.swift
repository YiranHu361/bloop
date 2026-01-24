import SwiftUI
import Charts

/// Live exposure visualization showing timeline chart and recent dB readings.
/// HealthKit provides loudness levels (dB), not frequency spectrum data.
struct ExposureProfileView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case timeline = "Timeline"
        case zones = "Zones"
        case log = "Log"

        var id: String { rawValue }
    }

    let bands: [ExposureBand]
    let timeline: [ExposureTimelinePoint]
    let currentLevelDB: Double?
    let descriptorText: String?
    var lastUpdated: Date?

    @State private var mode: Mode = .timeline
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with mode picker
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Exposure")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.label)

                    if let lastUpdated {
                        Text("Updated \(lastUpdated, style: .relative) ago")
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }

                Spacer()

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            // Current level indicator (always visible)
            if let currentLevelDB {
                currentLevelBanner(level: currentLevelDB)
            }

            // Content based on mode
            switch mode {
            case .timeline:
                timelineChart
            case .zones:
                zonesView
            case .log:
                recentLogView
            }

            // Summary text
            if let descriptorText {
                Text(descriptorText)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderGradient, lineWidth: 0.5)
        )
        .shadow(color: AppColors.glassShadow.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    // MARK: - Current Level Banner

    private func currentLevelBanner(level: Double) -> some View {
        HStack(spacing: 12) {
            // Pulsing indicator
            ZStack {
                Circle()
                    .fill(colorForLevel(level).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(colorForLevel(level).opacity(0.4))
                    .frame(width: 32, height: 32)
                
                Text("\(Int(level))")
                    .font(AppTypography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(colorForLevel(level))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Current Level")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                    
                    Circle()
                        .fill(AppColors.safe)
                        .frame(width: 6, height: 6)
                    
                    Text("Live")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                
                Text("\(Int(level)) dB • \(DoseCalculator.levelDescription(level))")
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.label)
            }
            
            Spacer()
            
            // Risk badge
            Text(riskLabel(for: level))
                .font(AppTypography.caption1Bold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(colorForLevel(level))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorForLevel(level).opacity(0.08))
        )
    }

    // MARK: - Timeline Chart

    private var timelineChart: some View {
        Group {
            if timeline.isEmpty {
                emptyStateView(message: "No exposure data yet today", icon: "waveform.path")
            } else {
                VStack(spacing: 8) {
                    Chart(timeline) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("dB", point.levelDB)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.safe, AppColors.caution, AppColors.danger],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Time", point.date),
                            yStart: .value("Start", 40),
                            yEnd: .value("dB", point.levelDB)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AppColors.primaryFallback.opacity(0.01),
                                    AppColors.primaryFallback.opacity(0.15)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                    .chartYScale(domain: 40...110)
                    .chartYAxis {
                        AxisMarks(values: [50, 70, 85, 100]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                .foregroundStyle(AppColors.tertiaryLabel.opacity(0.5))
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)")
                                        .font(AppTypography.chartLabel)
                                        .foregroundColor(intValue >= 85 ? AppColors.caution : AppColors.tertiaryLabel)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: .dateTime.hour().minute())
                                .font(AppTypography.chartLabel)
                        }
                    }
                    .chartPlotStyle { plotArea in
                        plotArea
                            .background(Color.clear)
                    }
                    .frame(height: 140)
                    
                    // Risk threshold legend
                    HStack(spacing: 16) {
                        legendItem(color: AppColors.safe, label: "Safe (<70)")
                        legendItem(color: AppColors.caution, label: "Caution (70-85)")
                        legendItem(color: AppColors.danger, label: "Risk (>85)")
                    }
                    .font(AppTypography.caption2)
                }
            }
        }
    }

    // MARK: - Zones View (improved labels)

    private var zonesView: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let maxHeight = geo.size.height - 24
                let maxValue = max(1, bands.map(\.seconds).max() ?? 1)

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(bands) { band in
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(band.color)
                                .frame(
                                    width: 28,
                                    height: max(4, maxHeight * CGFloat(band.seconds / maxValue))
                                )
                                .animation(.easeInOut(duration: 0.35), value: band.seconds)
                            
                            // dB range label (clearer than Q/M1/etc)
                            Text(band.label)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(AppColors.tertiaryLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(band.label): \(band.formattedTime)")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 130)

            // Legend
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(AppColors.safe).frame(width: 8, height: 8)
                    Text("Safe")
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(AppColors.caution).frame(width: 8, height: 8)
                    Text("Caution")
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(AppColors.danger).frame(width: 8, height: 8)
                    Text("Risk")
                }
            }
            .font(AppTypography.caption2)
            .foregroundColor(AppColors.secondaryLabel)
        }
    }

    // MARK: - Recent Log View

    private var recentLogView: some View {
        Group {
            if timeline.isEmpty {
                emptyStateView(message: "No readings logged yet", icon: "list.bullet")
            } else {
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("Time")
                            .frame(width: 70, alignment: .leading)
                        Text("Level")
                            .frame(width: 60, alignment: .center)
                        Text("Status")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(AppTypography.caption1Bold)
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Recent readings (last 10, reversed to show newest first)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(timeline.suffix(10).reversed().enumerated()), id: \.element.id) { index, point in
                                logRow(point: point, isNewest: index == 0)
                                
                                if index < min(9, timeline.count - 1) {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .frame(height: 140)
                }
            }
        }
    }

    private func logRow(point: ExposureTimelinePoint, isNewest: Bool) -> some View {
        HStack {
            Text(point.date, style: .time)
                .font(AppTypography.caption1)
                .foregroundColor(isNewest ? AppColors.label : AppColors.secondaryLabel)
                .frame(width: 70, alignment: .leading)
            
            Text("\(Int(point.levelDB)) dB")
                .font(isNewest ? AppTypography.subheadline : AppTypography.caption1)
                .fontWeight(isNewest ? .semibold : .regular)
                .foregroundColor(colorForLevel(point.levelDB))
                .frame(width: 60, alignment: .center)
            
            HStack(spacing: 6) {
                Circle()
                    .fill(colorForLevel(point.levelDB))
                    .frame(width: 8, height: 8)
                
                Text(riskLabel(for: point.levelDB))
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isNewest {
                Text("Latest")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.primaryFallback)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppColors.primaryFallback.opacity(0.15))
                    )
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helper Views

    private func emptyStateView(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(AppColors.tertiaryLabel)
            
            Text(message)
                .font(AppTypography.body)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(AppColors.tertiaryLabel)
        }
    }

    // MARK: - Styling

    private var glassBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.15)
            } else {
                Color.white.opacity(0.6)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.glassBorder.opacity(colorScheme == .dark ? 0.2 : 0.4),
                AppColors.glassBorder.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Helpers

    private func colorForLevel(_ level: Double) -> Color {
        if level >= 90 { return AppColors.danger }
        if level >= 85 { return AppColors.caution }
        if level >= 70 { return AppColors.caution.opacity(0.8) }
        return AppColors.safe
    }

    private func riskLabel(for level: Double) -> String {
        if level >= 100 { return "Extreme" }
        if level >= 90 { return "High Risk" }
        if level >= 85 { return "Risk" }
        if level >= 70 { return "Moderate" }
        return "Safe"
    }
}

// MARK: - Supporting Types

struct ExposureBand: Identifiable {
    let id: String
    let label: String
    let shortLabel: String
    let seconds: Double
    let color: Color

    var formattedTime: String {
        DoseCalculator.formatDuration(seconds)
    }
}

struct ExposureTimelinePoint: Identifiable {
    let id: UUID = UUID()
    let date: Date
    let levelDB: Double
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ExposureProfileView(
                bands: [
                    .init(id: "1", label: "<60", shortLabel: "<60", seconds: 900, color: AppColors.safe),
                    .init(id: "2", label: "60-70", shortLabel: "60-70", seconds: 1200, color: AppColors.safe.opacity(0.85)),
                    .init(id: "3", label: "70-80", shortLabel: "70-80", seconds: 1500, color: AppColors.safe.opacity(0.7)),
                    .init(id: "4", label: "80-85", shortLabel: "80-85", seconds: 600, color: AppColors.caution.opacity(0.85)),
                    .init(id: "5", label: "85-90", shortLabel: "85-90", seconds: 300, color: AppColors.caution),
                    .init(id: "6", label: "90-95", shortLabel: "90-95", seconds: 120, color: AppColors.danger.opacity(0.9)),
                    .init(id: "7", label: "95-100", shortLabel: "95-100", seconds: 60, color: AppColors.danger),
                    .init(id: "8", label: "100+", shortLabel: "100+", seconds: 20, color: AppColors.danger.opacity(0.75)),
                ],
                timeline: [
                    .init(date: .now.addingTimeInterval(-3600), levelDB: 62),
                    .init(date: .now.addingTimeInterval(-3000), levelDB: 68),
                    .init(date: .now.addingTimeInterval(-2400), levelDB: 74),
                    .init(date: .now.addingTimeInterval(-1800), levelDB: 82),
                    .init(date: .now.addingTimeInterval(-1200), levelDB: 91),
                    .init(date: .now.addingTimeInterval(-900), levelDB: 86),
                    .init(date: .now.addingTimeInterval(-600), levelDB: 78),
                    .init(date: .now.addingTimeInterval(-300), levelDB: 72),
                    .init(date: .now, levelDB: 68),
                ],
                currentLevelDB: 68,
                descriptorText: "Mostly moderate listening with a few loud peaks.",
                lastUpdated: Date()
            )
            .padding()
        }
    }
    .background(Color(UIColor.systemGroupedBackground))
}
