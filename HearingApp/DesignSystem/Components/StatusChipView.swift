import SwiftUI

/// Status indicator chip showing Safe/Caution/Danger
struct StatusChipView: View {
    let status: ExposureStatus
    let useGlassStyle: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(status: ExposureStatus, useGlassStyle: Bool = true) {
        self.status = status
        self.useGlassStyle = useGlassStyle
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .shadow(color: status.color.opacity(0.5), radius: useGlassStyle ? 4 : 0)

            Text(status.label)
                .font(AppTypography.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(chipBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(borderGradient, lineWidth: useGlassStyle ? 0.5 : 0)
        )
    }

    @ViewBuilder
    private var chipBackground: some View {
        if useGlassStyle {
            ZStack {
                status.color.opacity(colorScheme == .dark ? 0.15 : 0.1)
            }
            .background(.ultraThinMaterial)
        } else {
            status.color.opacity(0.15)
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                status.color.opacity(0.3),
                status.color.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ExposureStatus {
    var label: String {
        return displayName
    }
    
    var color: Color {
        switch self {
        case .safe: return AppColors.safe
        case .moderate: return AppColors.caution
        case .high: return AppColors.caution
        case .dangerous: return AppColors.danger
        }
    }
    
    var icon: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .dangerous: return "xmark.circle.fill"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusChipView(status: .safe)
        StatusChipView(status: .moderate)
        StatusChipView(status: .high)
        StatusChipView(status: .dangerous)
    }
    .padding()
}
