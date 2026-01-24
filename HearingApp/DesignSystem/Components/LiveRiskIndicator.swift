import SwiftUI

/// Large circular risk indicator for dashboard
struct LiveRiskIndicator: View {
    let dosePercent: Double
    let currentLevelDB: Double?
    let isMonitoring: Bool

    @State private var isAnimated = false

    private var status: ExposureStatus {
        ExposureStatus.from(dosePercent: dosePercent)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 28)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(dosePercent / 100, 1.0))
                .stroke(
                    AppColors.color(for: status),
                    style: StrokeStyle(lineWidth: 28, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: dosePercent)

            // Center content
            VStack(spacing: 8) {
                Text("\(Int(dosePercent))%")
                    .font(AppTypography.dosePercentLarge)
                    .foregroundColor(AppColors.label)

                Text(status.displayName)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.color(for: status))

                if let level = currentLevelDB {
                    Text("\(Int(level)) dB")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }

                if !isMonitoring {
                    Label("Paused", systemImage: "pause.circle")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        }
        .scaleEffect(isAnimated ? 1.0 : 0.9)
        .opacity(isAnimated ? 1.0 : 0)
        .onAppear {
            withAnimation(AnimationTokens.defaultSpring.delay(0.2)) {
                isAnimated = true
            }
        }
    }
}
