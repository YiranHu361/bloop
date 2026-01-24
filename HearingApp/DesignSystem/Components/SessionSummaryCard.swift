import SwiftUI

/// Session summary card showing key metrics: dB level, listening time
struct SessionSummaryCard: View {
    let averageDB: Double?
    let peakDB: Double?
    let listeningTime: TimeInterval
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryFallback)
                
                Text("Today's Session")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
                
                Spacer()
                
                Text("Live")
                    .font(AppTypography.caption1Bold)
                    .foregroundColor(AppColors.safe)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.safe.opacity(0.15))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Stats Grid
            HStack(spacing: 0) {
                // Average dB
                statItem(
                    icon: "waveform",
                    value: averageDB != nil ? "\(Int(averageDB!)) dB" : "—",
                    label: "Avg Level",
                    color: levelColor(for: averageDB ?? 0)
                )
                
                verticalDivider
                
                // Listening Time
                statItem(
                    icon: "clock",
                    value: formatDuration(listeningTime),
                    label: "Duration",
                    color: AppColors.primaryFallback
                )
            }
            .padding(.vertical, 16)
            
            // Peak level banner if high
            if let peak = peakDB, peak >= 85 {
                peakWarningBanner(level: peak)
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
    
    // MARK: - Subviews
    
    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            
            Text(value)
                .font(AppTypography.statNumberMedium)
                .foregroundColor(AppColors.label)
            
            Text(label)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1, height: 50)
    }
    
    private func peakWarningBanner(level: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            
            Text("Peak: \(Int(level)) dB")
                .font(AppTypography.caption1Bold)
            
            Spacer()
            
            Text("Loud exposure detected")
                .font(AppTypography.caption2)
        }
        .foregroundColor(AppColors.danger)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.danger.opacity(0.1))
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
    
    private func levelColor(for db: Double) -> Color {
        switch db {
        case ..<70: return AppColors.safe
        case 70..<85: return AppColors.caution
        case 85..<95: return AppColors.warning
        default: return AppColors.danger
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SessionSummaryCard(
            averageDB: 72,
            peakDB: 78,
            listeningTime: 2.5 * 3600
        )
        
        SessionSummaryCard(
            averageDB: 86,
            peakDB: 95,
            listeningTime: 4 * 3600
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
