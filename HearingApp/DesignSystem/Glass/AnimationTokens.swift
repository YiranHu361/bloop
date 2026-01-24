import SwiftUI

/// Animation tokens for consistent animations
enum AnimationTokens {
    static let defaultSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let standardEase = Animation.easeInOut(duration: 0.3)
}

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

extension View {
    func cardEntrance(delay: Double = 0) -> some View {
        modifier(CardEntranceModifier(delay: delay))
    }
}
