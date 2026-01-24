import SwiftUI

/// A reusable glass card component with blur, gradient border, and layered shadows.
/// Adapts to light/dark mode automatically.
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
            .shadow(color: AppColors.glassShadow.opacity(0.05), radius: 20, x: 0, y: 10)
    }

    private var glassBackground: some View {
        ZStack {
            // Base blur material
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

// MARK: - Glass Card Variants

/// A compact glass card with smaller corner radius and padding
struct CompactGlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GlassCard(cornerRadius: 12, padding: 12, content: content)
    }
}

/// A section glass card with header support
struct SectionGlassCard<Content: View>: View {
    let title: String?
    let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
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
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.glassBorder.opacity(colorScheme == .dark ? 0.2 : 0.4),
                            AppColors.glassBorder.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
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
}

// MARK: - View Extension

extension View {
    /// Applies glass card styling to any view
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Applies compact glass styling
    func compactGlassCard() -> some View {
        modifier(GlassCardModifier(cornerRadius: 12, padding: 12))
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderGradient, lineWidth: 1)
            )
            .shadow(color: AppColors.glassShadow.opacity(0.1), radius: 8, x: 0, y: 4)
            .shadow(color: AppColors.glassShadow.opacity(0.05), radius: 20, x: 0, y: 10)
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

#Preview {
    ZStack {
        GradientBackground()

        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("A beautiful frosted glass effect")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CompactGlassCard {
                HStack {
                    Image(systemName: "ear.badge.waveform")
                        .font(.title2)
                    Text("Compact Style")
                }
            }

            SectionGlassCard(title: "Section Header") {
                Text("Content goes here")
            }
        }
        .padding()
    }
}
