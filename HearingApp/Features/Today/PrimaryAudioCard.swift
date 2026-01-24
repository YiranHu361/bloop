import SwiftUI

/// Primary dashboard card showing Exposure Zones visualization.
/// Shows time spent at each dB level.
struct PrimaryAudioCard: View {
    let bands: [ExposureBand]
    let currentLevelDB: Double?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            // Header
            header

            // Zones content
            zonesContent
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
        .shadow(color: AppColors.cardShadow, radius: 12, x: 0, y: 6)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryFallback)

                Text("Exposure Zones")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
            }

            Spacer()

            if currentLevelDB != nil {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.safe)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
        }
    }

    // MARK: - Zones Content

    private var zonesContent: some View {
        VStack(spacing: 12) {
            // Current level banner (if available)
            if let level = currentLevelDB {
                currentLevelBanner(level: level)
            }

            // Zone bars
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

                            // dB range label
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

                Text("\(Int(level)) dB \(DoseCalculator.levelDescription(level))")
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

    // MARK: - Styling

    private var cardBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.25)
            } else {
                Color.white.opacity(0.95)
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

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            PrimaryAudioCard(
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
                currentLevelDB: 72
            )
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
