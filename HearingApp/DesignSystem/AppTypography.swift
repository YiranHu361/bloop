import SwiftUI

/// Centralized typography definitions
enum AppTypography {
    static let displayLarge = Font.system(size: 56, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 44, weight: .bold, design: .rounded)

    static let dosePercentLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let dosePercentMedium = Font.system(size: 36, weight: .bold, design: .rounded)

    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)

    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)

    static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let caption1Bold = Font.system(size: 12, weight: .semibold, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)

    static let statNumber = Font.system(size: 28, weight: .bold, design: .rounded)
    static let statNumberSmall = Font.system(size: 18, weight: .bold, design: .rounded)

    static let buttonLarge = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let buttonMedium = Font.system(size: 15, weight: .semibold, design: .rounded)
}
