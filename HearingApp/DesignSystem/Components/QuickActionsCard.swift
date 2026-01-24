import SwiftUI

/// Quick actions card with monitoring controls
struct QuickActionsCard: View {
    @Binding var isMonitoringPaused: Bool
    var lastUpdated: Date?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var lastUpdatedText: String {
        guard let date = lastUpdated else { return "Syncing..." }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Pause/Resume Monitoring Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isMonitoringPaused.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isMonitoringPaused ? AppColors.secondaryLabel.opacity(0.12) : AppColors.safe.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isMonitoringPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isMonitoringPaused ? AppColors.secondaryLabel : AppColors.safe)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isMonitoringPaused ? "Resume" : "Pause")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.label)
                        
                        Text("Monitoring")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // Auto-sync indicator
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.safe)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(AppTypography.caption1Bold)
                        .foregroundColor(AppColors.safe)
                }
                
                Text(lastUpdatedText)
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.tertiaryLabel)
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

/// Individual quick action button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isActive ? 0.15 : 0.08))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(AppTypography.caption1Bold)
                        .foregroundColor(AppColors.label)
                    
                    Text(subtitle)
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Button style that scales on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        QuickActionsCard(
            isMonitoringPaused: .constant(false),
            lastUpdated: Date()
        )
        
        QuickActionsCard(
            isMonitoringPaused: .constant(true),
            lastUpdated: Date()
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
