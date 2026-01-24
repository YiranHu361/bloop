import SwiftUI

/// An alert banner for displaying warnings and notifications
struct AlertBanner: View {
    let type: AlertType
    let message: String
    var onDismiss: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false
    
    enum AlertType {
        case info
        case warning
        case danger
        case success
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger: return "exclamationmark.octagon.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return AppColors.primaryFallback
            case .warning: return AppColors.caution
            case .danger: return AppColors.danger
            case .success: return AppColors.safe
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(type.color)
            
            Text(message)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.label)
                .lineLimit(2)
            
            Spacer()
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(type.color.opacity(colorScheme == .dark ? 0.15 : 0.1))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

/// Dose warning banner specifically for dose thresholds
struct DoseWarningBanner: View {
    let dosePercent: Double
    var onDismiss: (() -> Void)?
    
    private var warningLevel: AlertBanner.AlertType {
        switch dosePercent {
        case ..<75: return .info
        case 75..<90: return .warning
        default: return .danger
        }
    }
    
    private var message: String {
        switch dosePercent {
        case 75..<90:
            return "⚠️ You've reached \(Int(dosePercent))% of your daily safe limit. Consider lowering volume."
        case 90..<100:
            return "🔴 You've reached \(Int(dosePercent))% of your daily limit. Take a break soon!"
        case 100...:
            return "⛔ You've exceeded your daily safe listening limit. Give your ears a rest."
        default:
            return "Your hearing is in safe zone today."
        }
    }
    
    var body: some View {
        if dosePercent >= 75 {
            AlertBanner(type: warningLevel, message: message, onDismiss: onDismiss)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        AlertBanner(
            type: .info,
            message: "Your daily listening data has been synced.",
            onDismiss: {}
        )
        
        AlertBanner(
            type: .warning,
            message: "⚠️ You've reached 75% of your daily safe limit.",
            onDismiss: {}
        )
        
        AlertBanner(
            type: .danger,
            message: "⛔ You've exceeded your daily safe listening limit.",
            onDismiss: {}
        )
        
        AlertBanner(
            type: .success,
            message: "Great job! You stayed within safe limits today.",
            onDismiss: {}
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
