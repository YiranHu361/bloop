import SwiftUI

/// Centralized color definitions for the app - SafeSound Design System
enum AppColors {
    // MARK: - Brand Colors
    static let primary = Color("Primary", bundle: nil)
    static let primaryFallback = Color(hex: "6366F1") // Indigo
    static let accent = Color(hex: "8B5CF6") // Violet
    
    // MARK: - Status Colors (Traffic Light System)
    static let safe = Color(hex: "10B981")      // Emerald - Safe zone
    static let caution = Color(hex: "F59E0B")   // Amber - Caution zone
    static let warning = Color(hex: "F97316")   // Orange - Warning zone
    static let danger = Color(hex: "EF4444")    // Red - Danger zone
    
    // MARK: - Semantic Status Colors
    static let moderate = caution
    static let high = warning
    static let dangerous = danger
    
    // MARK: - Background Colors
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    
    // MARK: - Surface Colors (for cards)
    static let surfaceLight = Color(hex: "FFFFFF")
    static let surfaceDark = Color(hex: "1F2937")
    
    // MARK: - Text Colors
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    
    // MARK: - Ring Colors
    static let ringBackground = Color(UIColor.systemGray5)
    static let ringTrack = Color(UIColor.systemGray4)
    
    // MARK: - Card Colors
    static let cardBackground = Color(UIColor.systemBackground)
    static let cardShadow = Color.black.opacity(0.08)

    // MARK: - Glass Effect Colors
    static let glassBorder = Color.white
    static let glassHighlight = Color.white.opacity(0.2)
    static let glassShadow = Color.black
    
    // MARK: - Gradient Definitions
    static let safeGradient = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cautionGradient = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Status-Based Helpers
    
    /// Returns an appropriate glass background color for a given exposure status
    static func glassBackground(for status: ExposureStatus) -> Color {
        switch status {
        case .safe:
            return safe.opacity(0.1)
        case .moderate:
            return caution.opacity(0.1)
        case .high:
            return warning.opacity(0.12)
        case .dangerous:
            return danger.opacity(0.15)
        }
    }

    /// Returns a gradient for glass card borders based on status
    static func glassBorderGradient(for status: ExposureStatus) -> LinearGradient {
        let statusColor = color(for: status)
        return LinearGradient(
            colors: [
                statusColor.opacity(0.3),
                statusColor.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Status color based on dose percentage
    static func statusColor(for dosePercent: Double) -> Color {
        switch dosePercent {
        case ..<50:
            return safe
        case 50..<75:
            return caution
        case 75..<100:
            return warning
        default:
            return danger
        }
    }
    
    // MARK: - Color from ExposureStatus
    static func color(for status: ExposureStatus) -> Color {
        switch status {
        case .safe:
            return safe
        case .moderate:
            return caution
        case .high:
            return warning
        case .dangerous:
            return danger
        }
    }
    
    // MARK: - Gradients for status
    static func gradient(for status: ExposureStatus) -> LinearGradient {
        switch status {
        case .safe:
            return safeGradient
        case .moderate:
            return cautionGradient
        case .high:
            return LinearGradient(
                colors: [warning, warning.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dangerous:
            return dangerGradient
        }
    }
    
    // MARK: - Ring gradient based on progress
    static func ringGradient(for dosePercent: Double) -> AngularGradient {
        let color = statusColor(for: dosePercent)
        return AngularGradient(
            gradient: Gradient(colors: [
                color.opacity(0.6),
                color,
                color.opacity(0.9)
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * min(dosePercent / 100, 1.5))
        )
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
