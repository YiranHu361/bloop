import SwiftUI

/// Gamified Safe Listening Score component (0-100)
struct SafeListeningScoreCard: View {
    let score: Int
    let streak: Int
    let trend: ScoreTrend
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedScore: Int = 0
    @State private var hasAppeared = false
    
    enum ScoreTrend {
        case up
        case down
        case stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return AppColors.safe
            case .down: return AppColors.danger
            case .stable: return AppColors.secondaryLabel
            }
        }
        
        var label: String {
            switch self {
            case .up: return "Improving"
            case .down: return "Declining"
            case .stable: return "Stable"
            }
        }
    }
    
    private var scoreColor: Color {
        switch score {
        case 80...: return AppColors.safe
        case 60..<80: return AppColors.caution
        case 40..<60: return AppColors.warning
        default: return AppColors.danger
        }
    }
    
    private var scoreGrade: String {
        switch score {
        case 90...: return "Excellent"
        case 80..<90: return "Great"
        case 70..<80: return "Good"
        case 60..<70: return "Fair"
        case 50..<60: return "Needs Work"
        default: return "At Risk"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryFallback)
                
                Text("Hearing Wellness Score")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
                
                Spacer()
                
                // Trend indicator
                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(trend.label)
                        .font(AppTypography.caption2)
                }
                .foregroundColor(trend.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(trend.color.opacity(0.12))
                )
            }
            
            HStack(spacing: 24) {
                // Score circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            scoreColor.opacity(0.2),
                            lineWidth: 8
                        )
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(animatedScore) / 100)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: scoreColor.opacity(0.4), radius: 4)
                    
                    // Score value
                    VStack(spacing: 2) {
                        Text("\(animatedScore)")
                            .font(AppTypography.statNumber)
                            .foregroundColor(AppColors.label)
                            .contentTransition(.numericText())
                        
                        Text(scoreGrade)
                            .font(AppTypography.caption2)
                            .foregroundColor(scoreColor)
                    }
                }
                .frame(width: 100, height: 100)
                
                // Stats
                VStack(alignment: .leading, spacing: 16) {
                    // Streak
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppColors.safe.opacity(0.12))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.safe)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(streak) days")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.label)
                            
                            Text("Safe streak")
                                .font(AppTypography.caption1)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                    
                    // Weekly summary
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryFallback.opacity(0.12))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.primaryFallback)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("This Week")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.label)
                            
                            Text("View details")
                                .font(AppTypography.caption1)
                                .foregroundColor(AppColors.primaryFallback)
                        }
                    }
                }
                
                Spacer()
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
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            
            // Animate score counting up
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedScore = score
            }
        }
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

/// Calculate Safe Listening Score based on dose data
struct SafeListeningScoreCalculator {
    /// Calculate score from recent daily doses
    static func calculateScore(from doses: [DailyDose]) -> Int {
        guard !doses.isEmpty else { return 100 }
        
        var totalScore: Double = 0
        
        for dose in doses {
            // Perfect score for staying under 50%
            // Gradually decrease for higher doses
            let dayScore: Double
            switch dose.dosePercent {
            case ..<50:
                dayScore = 100
            case 50..<75:
                dayScore = 100 - ((dose.dosePercent - 50) * 1.0)
            case 75..<100:
                dayScore = 75 - ((dose.dosePercent - 75) * 1.5)
            default:
                dayScore = max(0, 37.5 - ((dose.dosePercent - 100) * 0.75))
            }
            totalScore += dayScore
        }
        
        return min(100, max(0, Int(totalScore / Double(doses.count))))
    }
    
    /// Calculate streak of days under 100%
    static func calculateStreak(from doses: [DailyDose]) -> Int {
        let sortedDoses = doses.sorted { $0.date > $1.date }
        var streak = 0
        
        for dose in sortedDoses {
            if dose.dosePercent < 100 {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    /// Determine trend based on recent vs older scores
    static func calculateTrend(recentDoses: [DailyDose], olderDoses: [DailyDose]) -> SafeListeningScoreCard.ScoreTrend {
        let recentAvg = recentDoses.isEmpty ? 0 : recentDoses.reduce(0.0) { $0 + $1.dosePercent } / Double(recentDoses.count)
        let olderAvg = olderDoses.isEmpty ? 0 : olderDoses.reduce(0.0) { $0 + $1.dosePercent } / Double(olderDoses.count)
        
        let difference = recentAvg - olderAvg
        
        if difference < -5 {
            return .up // Lower dose = improving
        } else if difference > 5 {
            return .down // Higher dose = declining
        } else {
            return .stable
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SafeListeningScoreCard(
            score: 85,
            streak: 7,
            trend: .up
        )
        
        SafeListeningScoreCard(
            score: 55,
            streak: 2,
            trend: .down
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
