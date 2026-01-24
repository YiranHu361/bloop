import Foundation

/// Represents the safety status based on daily dose percentage
enum ExposureStatus: String {
    case safe = "safe"
    case moderate = "moderate"
    case high = "high"
    case dangerous = "dangerous"

    static func from(dosePercent: Double) -> ExposureStatus {
        switch dosePercent {
        case 0..<50: return .safe
        case 50..<80: return .moderate
        case 80..<100: return .high
        default: return .dangerous
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
