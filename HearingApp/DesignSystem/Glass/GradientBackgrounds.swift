import SwiftUI

/// Gradient background for views
struct GradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "0f172a"), Color(hex: "1e1b4b")]
                : [Color(hex: "f8fafc"), Color(hex: "e0e7ff")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct MeshGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "1a1a2e"),
                Color(hex: "16213e"),
                Color(hex: "0f3460")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
