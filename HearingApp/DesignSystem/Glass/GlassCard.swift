import SwiftUI

/// A reusable glass card component with blur and gradient border
struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderGradient, lineWidth: 1)
            )
            .shadow(color: AppColors.glassShadow.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private var glassBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.2)
            } else {
                Color.white.opacity(0.5)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.glassBorder.opacity(colorScheme == .dark ? 0.3 : 0.5),
                AppColors.glassBorder.opacity(colorScheme == .dark ? 0.1 : 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct SectionGlassCard<Content: View>: View {
    let title: String?
    let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
            }
            content()
        }
        .padding(16)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderGradient, lineWidth: 0.5)
        )
        .shadow(color: AppColors.glassShadow.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var sectionBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.15)
            } else {
                Color.white.opacity(0.6)
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
