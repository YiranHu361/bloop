import Foundation

/// Represents the safety status based on daily dose percentage
enum ExposureStatus: String, CaseIterable {
    case safe = "safe"
    case moderate = "moderate" 
    case high = "high"
    case dangerous = "dangerous"
    
    static func from(dosePercent: Double) -> ExposureStatus {
        switch dosePercent {
        case 0..<50:
            return .safe
        case 50..<80:
            return .moderate
        case 80..<100:
            return .high
        default:
            return .dangerous
        }
    }
    
    var displayName: String {
        switch self {
        case .safe:
            return "Safe"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        case .dangerous:
            return "Dangerous"
        }
    }
    
    var description: String {
        switch self {
        case .safe:
            return "Your hearing exposure is within safe limits"
        case .moderate:
            return "Approaching recommended daily limit"
        case .high:
            return "Near daily limit - consider reducing volume"
        case .dangerous:
            return "Exceeded safe daily limit - lower volume immediately"
        }
    }
}
