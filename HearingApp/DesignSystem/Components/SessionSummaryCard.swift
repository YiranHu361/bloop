import SwiftUI

/// Session summary statistics card
struct SessionSummaryCard: View {
    let averageDB: Double?
    let peakDB: Double?
    let listeningTime: Double
    let dosePercent: Double

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryFallback)

                Text("Session Summary")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(title: "Avg Level", value: averageDB.map { "\(Int($0)) dB" } ?? "--", icon: "waveform")
                StatItem(title: "Peak Level", value: peakDB.map { "\(Int($0)) dB" } ?? "--", icon: "arrow.up.to.line")
                StatItem(title: "Listen Time", value: formatTime(listeningTime), icon: "clock")
                StatItem(title: "Dose", value: "\(Int(dosePercent))%", icon: "gauge", color: AppColors.statusColor(for: dosePercent))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
        .shadow(color: AppColors.cardShadow, radius: 8, x: 0, y: 4)
    }

    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private var cardBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.2)
            } else {
                Color.white.opacity(0.9)
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
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = AppColors.primaryFallback

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(AppTypography.statNumberSmall)
                .foregroundColor(AppColors.label)

            Text(title)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
