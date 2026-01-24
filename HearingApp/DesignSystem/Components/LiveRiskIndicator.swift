import SwiftUI

/// A dynamic, animated live risk indicator showing current hearing safety status
struct LiveRiskIndicator: View {
    let dosePercent: Double
    let currentLevelDB: Double?
    let isMonitoring: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedProgress: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var hasAppeared = false
    
    private var status: ExposureStatus {
        ExposureStatus.from(dosePercent: dosePercent)
    }
    
    private var statusColor: Color {
        AppColors.statusColor(for: dosePercent)
    }
    
    private var progress: Double {
        min(animatedProgress / 100.0, 1.5)
    }
    
    var body: some View {
        ZStack {
            // Ambient glow background
            ambientGlow
            
            // Outer track ring
            Circle()
                .stroke(trackColor, lineWidth: 28)
                .padding(4)
            
            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: 28, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: statusColor.opacity(0.6), radius: 12, x: 0, y: 0)
                .padding(4)
            
            // Inner glass disc
            glassDisc
            
            // Center content
            centerContent
            
            // Pulse animation for active monitoring
            if isMonitoring {
                pulseRing
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            withAnimation(AnimationTokens.smoothSpring.delay(0.2)) {
                animatedProgress = dosePercent
            }
            startPulseAnimation()
            startGlowAnimation()
        }
        .onChange(of: dosePercent) { _, newValue in
            withAnimation(AnimationTokens.smoothSpring) {
                animatedProgress = newValue
            }
        }
    }
    
    // MARK: - Subviews
    
    private var ambientGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        statusColor.opacity(colorScheme == .dark ? 0.25 : 0.2),
                        statusColor.opacity(0.08),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .scaleEffect(1.3)
            .blur(radius: 30)
            .opacity(glowOpacity)
    }
    
    private var trackColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }
    
    private var gradientColors: [Color] {
        [
            statusColor.opacity(0.5),
            statusColor,
            statusColor.opacity(0.9)
        ]
    }
    
    private var glassDisc: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 150
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
            .padding(42)
    }
    
    private var centerContent: some View {
        VStack(spacing: 8) {
            // Main percentage
            Text("\(Int(dosePercent))%")
                .font(AppTypography.dosePercentLarge)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.label, AppColors.label.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentTransition(.numericText())
            
            // Status label
            Text(status.displayName)
                .font(AppTypography.headline)
                .foregroundColor(statusColor)
            
            // Current dB if available
            if let level = currentLevelDB {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption)
                    Text("\(Int(level)) dB")
                        .font(AppTypography.caption1Bold)
                }
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 4)
            }
            
            // Monitoring indicator
            if isMonitoring {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.safe)
                        .frame(width: 6, height: 6)
                    Text("Monitoring")
                        .font(AppTypography.caption2)
                }
                .foregroundColor(AppColors.tertiaryLabel)
                .padding(.top, 2)
            }
        }
    }
    
    private var pulseRing: some View {
        Circle()
            .stroke(statusColor.opacity(0.3), lineWidth: 2)
            .scaleEffect(pulseScale)
            .opacity(2 - pulseScale)
            .padding(4)
    }
    
    // MARK: - Animations
    
    private func startPulseAnimation() {
        guard isMonitoring else { return }
        withAnimation(
            Animation.easeInOut(duration: 2)
                .repeatForever(autoreverses: false)
        ) {
            pulseScale = 1.15
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 0.5
        }
    }
}

// MARK: - Risk Level Badge

struct RiskLevelBadge: View {
    let status: ExposureStatus
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
                .shadow(color: status.color.opacity(0.5), radius: 4)
            
            Text(status.displayName)
                .font(AppTypography.chip)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(status.color.opacity(colorScheme == .dark ? 0.15 : 0.1))
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            status.color.opacity(0.4),
                            status.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        LiveRiskIndicator(
            dosePercent: 35,
            currentLevelDB: 72,
            isMonitoring: true
        )
        .frame(width: 280, height: 280)
        
        LiveRiskIndicator(
            dosePercent: 78,
            currentLevelDB: 85,
            isMonitoring: true
        )
        .frame(width: 280, height: 280)
    }
    .padding()
    .background(Color(UIColor.systemBackground))
}
