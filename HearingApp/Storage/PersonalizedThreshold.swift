import Foundation
import SwiftData

/// SwiftData model for custom personalized thresholds
@Model
final class PersonalizedThreshold {
    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// Threshold percentage (e.g., 50, 80, 100)
    var percent: Int

    /// Whether this threshold is enabled
    var isEnabled: Bool

    /// Custom message for this threshold (nil uses default)
    var customMessage: String?

    /// Whether this threshold was adjusted based on user's average patterns
    var adjustedBasedOnAverage: Bool

    /// Original threshold before adjustment
    var originalPercent: Int?

    /// When this threshold was created/updated
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        percent: Int,
        isEnabled: Bool = true,
        customMessage: String? = nil,
        adjustedBasedOnAverage: Bool = false,
        originalPercent: Int? = nil
    ) {
        self.id = id
        self.percent = percent
        self.isEnabled = isEnabled
        self.customMessage = customMessage
        self.adjustedBasedOnAverage = adjustedBasedOnAverage
        self.originalPercent = originalPercent
        self.lastUpdated = Date()
    }
}

/// User's personalization preferences
@Model
final class PersonalizationPreferences {
    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// Whether personalization is enabled
    var isEnabled: Bool

    /// User's typical average dose (calculated from history)
    var typicalAverageDose: Double?

    /// Average weekday dose
    var weekdayAverageDose: Double?

    /// Average weekend dose
    var weekendAverageDose: Double?

    /// Peak listening hour (0-23)
    var peakListeningHour: Int?

    /// Days of data analyzed
    var daysAnalyzed: Int

    /// Last analysis date
    var lastAnalysisDate: Date?

    /// Recommended early warning threshold (personalized)
    var recommendedEarlyWarning: Int?

    /// User's listening pattern type
    var listeningPatternType: String?

    init(
        id: UUID = UUID(),
        isEnabled: Bool = false,
        typicalAverageDose: Double? = nil,
        weekdayAverageDose: Double? = nil,
        weekendAverageDose: Double? = nil,
        peakListeningHour: Int? = nil,
        daysAnalyzed: Int = 0,
        lastAnalysisDate: Date? = nil,
        recommendedEarlyWarning: Int? = nil,
        listeningPatternType: String? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.typicalAverageDose = typicalAverageDose
        self.weekdayAverageDose = weekdayAverageDose
        self.weekendAverageDose = weekendAverageDose
        self.peakListeningHour = peakListeningHour
        self.daysAnalyzed = daysAnalyzed
        self.lastAnalysisDate = lastAnalysisDate
        self.recommendedEarlyWarning = recommendedEarlyWarning
        self.listeningPatternType = listeningPatternType
    }

    // MARK: - Computed Properties

    var patternDescription: String {
        guard let pattern = listeningPatternType else {
            return "Unknown"
        }
        return pattern
    }

    var hasEnoughData: Bool {
        daysAnalyzed >= 7
    }

    var weekdayVsWeekendDifference: Double? {
        guard let weekday = weekdayAverageDose,
              let weekend = weekendAverageDose else {
            return nil
        }
        return weekend - weekday
    }
}

// MARK: - Listening Pattern Types

enum ListeningPatternType: String, CaseIterable {
    case conservative = "Conservative Listener"
    case moderate = "Moderate Listener"
    case heavy = "Heavy Listener"
    case inconsistent = "Inconsistent Patterns"
    case weekendWarrior = "Weekend Warrior"
    case workdayListener = "Workday Listener"

    var description: String {
        switch self {
        case .conservative:
            return "You typically stay well under your daily limit. Great hearing hygiene!"
        case .moderate:
            return "You use a balanced amount of your daily allowance."
        case .heavy:
            return "You frequently approach or exceed your daily limit."
        case .inconsistent:
            return "Your listening patterns vary significantly day-to-day."
        case .weekendWarrior:
            return "You tend to listen more on weekends than weekdays."
        case .workdayListener:
            return "You tend to listen more during the workweek."
        }
    }

    var recommendation: String {
        switch self {
        case .conservative:
            return "Your current thresholds work well for you."
        case .moderate:
            return "Consider an earlier 40% warning to maintain your good habits."
        case .heavy:
            return "Earlier warnings at 40% and 60% may help you pace your listening."
        case .inconsistent:
            return "Consistent daily habits could help protect your hearing better."
        case .weekendWarrior:
            return "Be extra mindful on weekends when you tend to listen more."
        case .workdayListener:
            return "Your weekends are giving your ears a good rest."
        }
    }
}
