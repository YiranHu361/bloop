import SwiftUI

/// A card displaying a single statistic with label
struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let color: Color
    let useGlassStyle: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        color: Color = AppColors.primaryFallback,
        useGlassStyle: Bool = true
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.useGlassStyle = useGlassStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }

            Text(value)
                .font(AppTypography.statNumber)
                .foregroundColor(AppColors.label)

            // Always reserve space for subtitle to keep cards aligned
            Text(subtitle ?? " ")
                .font(AppTypography.caption2)
                .foregroundColor(subtitle != nil ? AppColors.tertiaryLabel : .clear)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderGradient, lineWidth: useGlassStyle ? 0.5 : 0)
        )
        .shadow(color: useGlassStyle ? AppColors.glassShadow.opacity(0.06) : .clear, radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if useGlassStyle {
            ZStack {
                if colorScheme == .dark {
                    Color.black.opacity(0.15)
                } else {
                    Color.white.opacity(0.6)
                }
            }
            .background(.ultraThinMaterial)
        } else {
            AppColors.secondaryBackground
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.glassBorder.opacity(colorScheme == .dark ? 0.15 : 0.3),
                AppColors.glassBorder.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            StatCardView(
                title: "Average Level",
                value: "72 dB",
                subtitle: "This week",
                icon: "speaker.wave.2",
                color: AppColors.safe
            )
            
            StatCardView(
                title: "Safe Days",
                value: "5",
                subtitle: "In a row",
                icon: "checkmark.shield",
                color: AppColors.safe
            )
        }
        
        StatCardView(
            title: "Time at Risk",
            value: "1h 23m",
            subtitle: "Above 85 dB today",
            icon: "exclamationmark.triangle",
            color: AppColors.caution
        )
    }
    .padding()
}
