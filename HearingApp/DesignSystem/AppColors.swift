import SwiftUI

/// Centralized color definitions - SafeSound Design System
enum AppColors {
    static let primary = Color("Primary", bundle: nil)
    static let primaryFallback = Color(hex: "6366F1")
    static let accent = Color(hex: "8B5CF6")

    static let safe = Color(hex: "10B981")
    static let caution = Color(hex: "F59E0B")
    static let warning = Color(hex: "F97316")
    static let danger = Color(hex: "EF4444")

    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)

    static let cardShadow = Color.black.opacity(0.08)
    static let glassBorder = Color.white
    static let glassShadow = Color.black

    static func statusColor(for dosePercent: Double) -> Color {
        switch dosePercent {
        case ..<50: return safe
        case 50..<75: return caution
        case 75..<100: return warning
        default: return danger
        }
    }

    static func color(for status: ExposureStatus) -> Color {
        switch status {
        case .safe: return safe
        case .moderate: return caution
        case .high: return warning
        case .dangerous: return danger
        }
    }

    static func gradient(for status: ExposureStatus) -> LinearGradient {
        let color = self.color(for: status)
        return LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
