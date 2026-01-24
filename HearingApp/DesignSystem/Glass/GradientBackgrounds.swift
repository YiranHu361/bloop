import SwiftUI

/// Ambient gradient background with colored orbs for the main app
struct GradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: baseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Ambient orbs
                Circle()
                    .fill(orbColor1.opacity(orbOpacity))
                    .frame(width: geometry.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.2)

                Circle()
                    .fill(orbColor2.opacity(orbOpacity))
                    .frame(width: geometry.size.width * 0.6)
                    .blur(radius: 60)
                    .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.3)

                Circle()
                    .fill(orbColor3.opacity(orbOpacity * 0.7))
                    .frame(width: geometry.size.width * 0.4)
                    .blur(radius: 50)
                    .offset(x: 0, y: geometry.size.height * 0.15)
            }
        }
        .ignoresSafeArea()
    }

    private var baseColors: [Color] {
        colorScheme == .dark
            ? [Color(hex: "0A0E14"), Color(hex: "111827")]
            : [Color(hex: "F8FAFC"), Color(hex: "E2E8F0")]
    }

    private var orbColor1: Color {
        colorScheme == .dark
            ? Color(hex: "6366F1")  // Indigo
            : Color(hex: "818CF8")
    }

    private var orbColor2: Color {
        colorScheme == .dark
            ? Color(hex: "8B5CF6")  // Violet
            : Color(hex: "A78BFA")
    }

    private var orbColor3: Color {
        colorScheme == .dark
            ? Color(hex: "06B6D4")  // Cyan
            : Color(hex: "22D3EE")
    }

    private var orbOpacity: Double {
        colorScheme == .dark ? 0.12 : 0.2
    }
}

/// Status-adaptive gradient background for the dose ring area
struct StatusGradientBackground: View {
    let status: ExposureStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base
                RadialGradient(
                    colors: [
                        statusColor.opacity(colorScheme == .dark ? 0.15 : 0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.6
                )

                // Glow effect
                Circle()
                    .fill(statusColor.opacity(colorScheme == .dark ? 0.1 : 0.15))
                    .frame(width: geometry.size.width * 0.5)
                    .blur(radius: 40)
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .safe:
            return AppColors.safe
        case .moderate, .high:
            return AppColors.caution
        case .dangerous:
            return AppColors.danger
        }
    }
}

/// Animated mesh gradient for onboarding and special screens
struct MeshGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep base gradient
                LinearGradient(
                    colors: baseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Animated orb 1
                Circle()
                    .fill(orbColor1.opacity(orbOpacity))
                    .frame(width: geometry.size.width * 0.7)
                    .blur(radius: 70)
                    .offset(
                        x: -geometry.size.width * 0.2 + sin(animationPhase) * 20,
                        y: -geometry.size.height * 0.15 + cos(animationPhase) * 15
                    )

                // Animated orb 2
                Circle()
                    .fill(orbColor2.opacity(orbOpacity))
                    .frame(width: geometry.size.width * 0.5)
                    .blur(radius: 50)
                    .offset(
                        x: geometry.size.width * 0.25 + cos(animationPhase * 0.8) * 25,
                        y: geometry.size.height * 0.25 + sin(animationPhase * 0.8) * 20
                    )

                // Animated orb 3
                Circle()
                    .fill(orbColor3.opacity(orbOpacity * 0.6))
                    .frame(width: geometry.size.width * 0.35)
                    .blur(radius: 40)
                    .offset(
                        x: geometry.size.width * 0.1 + sin(animationPhase * 1.2) * 15,
                        y: geometry.size.height * 0.4 + cos(animationPhase * 1.2) * 10
                    )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animationPhase = .pi * 2
            }
        }
    }

    private var baseColors: [Color] {
        [Color(hex: "0F0F1A"), Color(hex: "1A1A2E")]
    }

    private var orbColor1: Color {
        Color(hex: "6366F1")  // Indigo
    }

    private var orbColor2: Color {
        Color(hex: "8B5CF6")  // Violet
    }

    private var orbColor3: Color {
        Color(hex: "0EA5E9")  // Sky
    }

    private var orbOpacity: Double {
        0.25
    }
}

/// Simple solid background with subtle gradient (for lists/settings)
struct SubtleGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "0F172A"), Color(hex: "1E293B")]
                : [Color(hex: "F8FAFC"), Color(hex: "F1F5F9")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - View Extensions

extension View {
    /// Applies the main gradient background
    func gradientBackground() -> some View {
        self.background(GradientBackground())
    }

    /// Applies a status-adaptive gradient background
    func statusGradientBackground(for status: ExposureStatus) -> some View {
        self.background(StatusGradientBackground(status: status))
    }

    /// Applies mesh gradient for special screens
    func meshGradientBackground() -> some View {
        self.background(MeshGradientBackground())
    }

    /// Applies subtle gradient for lists
    func subtleGradientBackground() -> some View {
        self.background(SubtleGradientBackground())
    }
}
