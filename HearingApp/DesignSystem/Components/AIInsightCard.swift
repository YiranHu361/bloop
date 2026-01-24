import SwiftUI

/// Card displaying AI-powered hearing budget insights and ETA predictions
struct AIInsightCard: View {
    let dosePercent: Double
    let insight: AIInsight
    let lastUpdated: Date?

    @Environment(\.colorScheme) private var colorScheme
    @State private var showLowerVolumeTip = false
    @State private var showTakeBreakTip = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.horizontal, 16)

            // Progress Bar
            progressSection
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // AI Insight Message
            insightSection
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Action Buttons (if near limit)
            if shouldShowActions {
                actionSection
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
        .shadow(color: AppColors.cardShadow, radius: 8, x: 0, y: 4)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.primaryFallback)

            Text("Hearing Budget")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.label)

            Spacer()

            if let updated = lastUpdated {
                Text(timeAgoString(from: updated))
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(Int(min(dosePercent, 200)))%")
                    .font(AppTypography.statNumberMedium)
                    .foregroundColor(statusColor)

                Text("of daily budget used")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.secondaryLabel)

                Spacer()

                if let eta = insight.etaToLimit, insight.isActivelyListening {
                    etaBadge(seconds: eta)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressGradient)
                        .frame(width: progressWidth(in: geometry.size.width), height: 12)

                    // Threshold markers
                    thresholdMarkers(in: geometry.size.width)
                }
            }
            .frame(height: 12)
        }
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let percent = min(dosePercent / 100.0, 1.5) // Cap at 150% visually
        return totalWidth * CGFloat(percent) / 1.5
    }

    private func thresholdMarkers(in totalWidth: CGFloat) -> some View {
        ZStack {
            // 50% marker
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 2, height: 16)
                .offset(x: totalWidth * (50.0 / 150.0) - 1)

            // 80% marker
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 2, height: 16)
                .offset(x: totalWidth * (80.0 / 150.0) - 1)

            // 100% marker
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 2, height: 20)
                .offset(x: totalWidth * (100.0 / 150.0) - 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [statusColor.opacity(0.8), statusColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func etaBadge(seconds: TimeInterval) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .semibold))

            Text(formatETA(seconds))
                .font(AppTypography.caption1Bold)
        }
        .foregroundColor(etaBadgeColor(seconds: seconds))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(etaBadgeColor(seconds: seconds).opacity(0.15))
        )
    }

    private func etaBadgeColor(seconds: TimeInterval) -> Color {
        if seconds < 30 * 60 { return AppColors.danger }
        if seconds < 2 * 3600 { return AppColors.caution }
        return AppColors.safe
    }

    // MARK: - Insight Section

    private var insightSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Insight icon
            ZStack {
                Circle()
                    .fill(insightIconBackground)
                    .frame(width: 36, height: 36)

                Image(systemName: insightIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(insightIconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(insightTitle)
                    .font(AppTypography.footnoteBold)
                    .foregroundColor(insightIconColor)

                Text(insight.message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var insightTitle: String {
        switch insight.type {
        case .safe: return "On Track"
        case .warning: return "Heads Up"
        case .danger: return "Take Action"
        case .inactive: return "Ready to Listen"
        case .recovering: return "Recovering"
        }
    }

    private var insightIcon: String {
        switch insight.type {
        case .safe: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        case .inactive: return "headphones"
        case .recovering: return "arrow.down.circle.fill"
        }
    }

    private var insightIconColor: Color {
        switch insight.type {
        case .safe: return AppColors.safe
        case .warning: return AppColors.caution
        case .danger: return AppColors.danger
        case .inactive: return AppColors.secondaryLabel
        case .recovering: return AppColors.safe
        }
    }

    private var insightIconBackground: Color {
        insightIconColor.opacity(0.15)
    }

    // MARK: - Action Section

    private var shouldShowActions: Bool {
        insight.type == .warning || insight.type == .danger
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
            actionButton(
                title: "Lower Volume",
                icon: "speaker.minus.fill",
                style: .primary,
                action: { showLowerVolumeTip = true }
            )

            actionButton(
                title: "Take a Break",
                icon: "pause.circle.fill",
                style: .secondary,
                action: { showTakeBreakTip = true }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .alert("Lower Your Volume", isPresented: $showLowerVolumeTip) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Try reducing your volume by 10-20%. Even a small reduction can significantly extend your safe listening time. Every 3 dB lower doubles the time you can listen safely.")
        }
        .alert("Take a Break", isPresented: $showTakeBreakTip) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Give your ears a 5-10 minute break to help them recover. Step away from headphones and enjoy some quiet time. Your hearing will thank you!")
        }
    }

    private enum ActionButtonStyle {
        case primary, secondary
    }

    private func actionButton(title: String, icon: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(AppTypography.buttonSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                style == .primary
                    ? AnyShapeStyle(statusColor.opacity(0.15))
                    : AnyShapeStyle(Color.gray.opacity(0.1))
            )
            .foregroundColor(style == .primary ? statusColor : AppColors.secondaryLabel)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Styling Helpers

    private var statusColor: Color {
        AppColors.statusColor(for: dosePercent)
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

    // MARK: - Formatting Helpers

    private func formatETA(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m left"
            }
            return "\(hours)h left"
        }
        return "\(minutes)m left"
    }

    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)

        if seconds < 5 {
            return "Just now"
        } else if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Safe state
            AIInsightCard(
                dosePercent: 35,
                insight: AIInsight(
                    type: .safe,
                    message: "Looking good! At this pace, you have 4h 30m of safe listening remaining.",
                    etaToLimit: 4.5 * 3600,
                    estimatedLimitTime: Date().addingTimeInterval(4.5 * 3600),
                    burnRatePerHour: 15,
                    isActivelyListening: true
                ),
                lastUpdated: Date()
            )

            // Warning state
            AIInsightCard(
                dosePercent: 72,
                insight: AIInsight(
                    type: .warning,
                    message: "At your current pace, you'll hit 100% by 4:30 PM. You have 1h 45m left.",
                    etaToLimit: 1.75 * 3600,
                    estimatedLimitTime: Date().addingTimeInterval(1.75 * 3600),
                    burnRatePerHour: 25,
                    isActivelyListening: true
                ),
                lastUpdated: Date().addingTimeInterval(-30)
            )

            // Danger state
            AIInsightCard(
                dosePercent: 95,
                insight: AIInsight(
                    type: .danger,
                    message: "At this pace, you'll hit your limit in 15 minutes. Consider lowering volume now.",
                    etaToLimit: 15 * 60,
                    estimatedLimitTime: Date().addingTimeInterval(15 * 60),
                    burnRatePerHour: 40,
                    isActivelyListening: true
                ),
                lastUpdated: Date().addingTimeInterval(-10)
            )

            // Inactive state
            AIInsightCard(
                dosePercent: 45,
                insight: .inactive,
                lastUpdated: Date().addingTimeInterval(-300)
            )
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
