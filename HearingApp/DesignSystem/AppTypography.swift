import SwiftUI

/// Centralized typography definitions for the app - SafeSound Design System
enum AppTypography {
    // MARK: - Display Fonts (for large numbers, headlines)
    static let displayLarge = Font.system(size: 56, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 44, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 36, weight: .bold, design: .rounded)
    
    // MARK: - Dose Percentage (main ring display)
    static let dosePercentLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let dosePercentMedium = Font.system(size: 36, weight: .bold, design: .rounded)
    static let dosePercentSmall = Font.system(size: 24, weight: .bold, design: .rounded)
    
    // MARK: - Headlines
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    
    // MARK: - Body Text
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    
    // MARK: - Supporting Text
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let footnoteBold = Font.system(size: 13, weight: .semibold, design: .default)
    static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let caption1Bold = Font.system(size: 12, weight: .semibold, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // MARK: - Stat Numbers
    static let statNumber = Font.system(size: 28, weight: .bold, design: .rounded)
    static let statNumberMedium = Font.system(size: 22, weight: .bold, design: .rounded)
    static let statNumberSmall = Font.system(size: 18, weight: .bold, design: .rounded)
    static let statLabel = Font.system(size: 12, weight: .medium, design: .default)
    
    // MARK: - Button Text
    static let buttonLarge = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let buttonMedium = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let buttonSmall = Font.system(size: 13, weight: .semibold, design: .rounded)
    
    // MARK: - Chip/Badge Text
    static let chip = Font.system(size: 14, weight: .medium, design: .rounded)
    static let badge = Font.system(size: 11, weight: .bold, design: .rounded)
    
    // MARK: - Chart Text
    static let chartLabel = Font.system(size: 10, weight: .medium, design: .default)
    static let chartValue = Font.system(size: 12, weight: .semibold, design: .rounded)
}

// MARK: - Text Style Modifiers

struct HeadlineStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.headline)
            .foregroundColor(AppColors.label)
    }
}

struct BodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.body)
            .foregroundColor(AppColors.label)
    }
}

struct CaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.caption1)
            .foregroundColor(AppColors.secondaryLabel)
    }
}

struct StatValueStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.statNumber)
            .foregroundColor(AppColors.label)
    }
}

extension View {
    func headlineStyle() -> some View {
        modifier(HeadlineStyle())
    }
    
    func bodyStyle() -> some View {
        modifier(BodyStyle())
    }
    
    func captionStyle() -> some View {
        modifier(CaptionStyle())
    }
    
    func statValueStyle() -> some View {
        modifier(StatValueStyle())
    }
}
