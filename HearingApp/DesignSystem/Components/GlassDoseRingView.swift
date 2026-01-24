import SwiftUI

/// Enhanced dose ring with glass background, ambient glow, and angular gradient progress
struct GlassDoseRingView: View {
    let dosePercent: Double
    let lineWidth: CGFloat
    let showLabel: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedProgress: Double = 0
    @State private var hasAppeared = false

    init(dosePercent: Double, lineWidth: CGFloat = 24, showLabel: Bool = true) {
        self.dosePercent = dosePercent
        self.lineWidth = lineWidth
        self.showLabel = showLabel
    }

    private var progress: Double {
        min(animatedProgress / 100.0, 1.5) // Cap at 150% for visual
    }

    private var statusColor: Color {
        AppColors.statusColor(for: dosePercent)
    }

    private var status: ExposureStatus {
        ExposureStatus.from(dosePercent: dosePercent)
    }

    var body: some View {
        ZStack {
            // Ambient glow background
            ambientGlow

            // Glass background disc
            glassDisc

            // Track ring
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            // Progress ring with angular gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: statusColor.opacity(0.5), radius: 8, x: 0, y: 0)

            // Overflow indicator (if > 100%)
            if dosePercent > 100 {
                overflowRing
            }

            // Center content
            if showLabel {
                centerLabel
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            withAnimation(AnimationTokens.smoothSpring.delay(0.2)) {
                animatedProgress = dosePercent
            }
        }
        .onChange(of: dosePercent) { _, newValue in
            withAnimation(AnimationTokens.smoothSpring) {
                animatedProgress = newValue
            }
        }
    }

    // MARK: - Components

    private var ambientGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        statusColor.opacity(colorScheme == .dark ? 0.2 : 0.15),
                        statusColor.opacity(0.05),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
            )
            .scaleEffect(1.4)
            .blur(radius: 20)
    }

    private var glassDisc: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.3),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppColors.glassBorder.opacity(colorScheme == .dark ? 0.2 : 0.4),
                                AppColors.glassBorder.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(lineWidth / 2 + 8)
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    private var progressGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                statusColor.opacity(0.6),
                statusColor,
                statusColor.opacity(0.9)
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * progress)
        )
    }

    private var overflowRing: some View {
        Circle()
            .trim(from: 0, to: min((dosePercent - 100) / 100.0, 0.5))
            .stroke(
                AppColors.danger.opacity(0.6),
                style: StrokeStyle(lineWidth: lineWidth / 2, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: AppColors.danger.opacity(0.4), radius: 6)
    }

    private var centerLabel: some View {
        VStack(spacing: 4) {
            Text("\(Int(dosePercent))%")
                .font(AppTypography.dosePercentLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.label,
                            AppColors.label.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentTransition(.numericText())

            Text("of daily limit")
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
        }
    }
}

// MARK: - Compact Variant

/// Smaller dose ring for widgets and compact displays
struct CompactDoseRingView: View {
    let dosePercent: Double

    @Environment(\.colorScheme) private var colorScheme

    private var statusColor: Color {
        AppColors.statusColor(for: dosePercent)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: 6
                )

            // Progress
            Circle()
                .trim(from: 0, to: min(dosePercent / 100.0, 1.0))
                .stroke(
                    statusColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage
            Text("\(Int(dosePercent))%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.label)
        }
    }
}

#Preview("Glass Dose Ring") {
    ZStack {
        GradientBackground()

        VStack(spacing: 40) {
            GlassDoseRingView(dosePercent: 35)
                .frame(width: 220, height: 220)

            GlassDoseRingView(dosePercent: 75)
                .frame(width: 220, height: 220)

            GlassDoseRingView(dosePercent: 120)
                .frame(width: 220, height: 220)
        }
    }
}

#Preview("Compact Ring") {
    HStack(spacing: 20) {
        CompactDoseRingView(dosePercent: 35)
            .frame(width: 50, height: 50)

        CompactDoseRingView(dosePercent: 75)
            .frame(width: 50, height: 50)

        CompactDoseRingView(dosePercent: 100)
            .frame(width: 50, height: 50)
    }
    .padding()
    .background(Color.black)
}
