import SwiftUI

/// Standardized animation curves and view modifiers for consistent UI animations
enum AnimationTokens {
    // MARK: - Spring Animations

    /// Default spring animation for most UI interactions
    static let defaultSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)

    /// Quick spring for small UI elements
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Bouncy spring for playful animations
    static let bouncySpring = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// Smooth spring for large elements
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.85)

    // MARK: - Ease Animations

    /// Standard ease in-out
    static let standardEase = Animation.easeInOut(duration: 0.3)

    /// Slow ease for gradual transitions
    static let slowEase = Animation.easeInOut(duration: 0.5)

    /// Quick ease for fast feedback
    static let quickEase = Animation.easeInOut(duration: 0.2)

    // MARK: - Timing

    /// Stagger delay for list items (multiply by index)
    static let staggerDelay: Double = 0.05

    /// Card entrance delay
    static let cardEntranceDelay: Double = 0.1
}

// MARK: - Card Entrance Animation Modifier

struct CardEntranceModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(AnimationTokens.defaultSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct StaggeredEntranceModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                let delay = Double(index) * AnimationTokens.staggerDelay
                withAnimation(AnimationTokens.defaultSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Ring Progress Animation

struct RingProgressModifier: ViewModifier {
    let progress: Double
    @State private var animatedProgress: Double = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(AnimationTokens.smoothSpring.delay(0.2)) {
                    animatedProgress = progress
                }
            }
            .onChange(of: progress) { _, newValue in
                withAnimation(AnimationTokens.smoothSpring) {
                    animatedProgress = newValue
                }
            }
    }
}

// MARK: - Pulse Animation

struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && isActive ? 1.05 : 1.0)
            .opacity(isPulsing && isActive ? 0.8 : 1.0)
            .onAppear {
                guard isActive else { return }
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isPulsing = false
                    }
                }
            }
    }
}

// MARK: - Glow Animation

struct GlowModifier: ViewModifier {
    let color: Color
    let isActive: Bool
    @State private var glowOpacity: Double = 0.3

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(glowOpacity) : .clear, radius: 10)
            .shadow(color: isActive ? color.opacity(glowOpacity * 0.5) : .clear, radius: 20)
            .onAppear {
                guard isActive else { return }
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.6
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies card entrance animation with optional delay
    func cardEntrance(delay: Double = 0) -> some View {
        modifier(CardEntranceModifier(delay: delay))
    }

    /// Applies staggered entrance animation based on index
    func staggeredEntrance(index: Int) -> some View {
        modifier(StaggeredEntranceModifier(index: index))
    }

    /// Applies subtle pulse animation when active
    func pulse(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }

    /// Applies animated glow effect
    func animatedGlow(color: Color, isActive: Bool = true) -> some View {
        modifier(GlowModifier(color: color, isActive: isActive))
    }

    /// Applies ring progress animation
    func ringProgressAnimation(progress: Double) -> some View {
        modifier(RingProgressModifier(progress: progress))
    }
}

// MARK: - Interactive Scale Effect

struct InteractiveScaleModifier: ViewModifier {
    @State private var isPressed = false
    let scale: CGFloat

    init(scale: CGFloat = 0.97) {
        self.scale = scale
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(AnimationTokens.quickSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    /// Adds interactive press scale effect
    func interactiveScale(_ scale: CGFloat = 0.97) -> some View {
        modifier(InteractiveScaleModifier(scale: scale))
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(0..<4, id: \.self) { index in
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.3))
                .frame(height: 60)
                .overlay(Text("Card \(index + 1)"))
                .staggeredEntrance(index: index)
        }

        Circle()
            .fill(Color.green)
            .frame(width: 60, height: 60)
            .pulse(isActive: true)

        RoundedRectangle(cornerRadius: 12)
            .fill(Color.purple)
            .frame(width: 100, height: 50)
            .animatedGlow(color: .purple, isActive: true)
            .interactiveScale()
    }
    .padding()
}
