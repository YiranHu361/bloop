import Foundation
import SwiftData

/// SwiftData model for storing weekly digest summaries
@Model
final class WeeklyDigest {
    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// Start date of the week (Monday)
    var weekStartDate: Date

    /// End date of the week (Sunday)
    var weekEndDate: Date

    /// Average dose percentage for the week
    var averageDosePercent: Double

    /// Previous week's average for comparison
    var previousWeekAveragePercent: Double?

    /// Total listening time in seconds
    var totalListeningTimeSeconds: Double

    /// Number of days with data
    var daysWithData: Int

    /// Number of days over 100% limit
    var daysOverLimit: Int

    /// Current safe listening streak (days)
    var currentStreak: Int

    /// Best streak ever recorded
    var bestStreak: Int

    /// Loudest day date
    var loudestDayDate: Date?

    /// Loudest day dose percent
    var loudestDayDosePercent: Double?

    /// Quietest day date
    var quietestDayDate: Date?

    /// Quietest day dose percent
    var quietestDayDosePercent: Double?

    /// Average dB level for the week
    var averageLevelDBASPL: Double?

    /// When this digest was generated
    var generatedAt: Date

    /// Year component for querying
    var year: Int

    /// Week of year for querying
    var weekOfYear: Int

    init(
        id: UUID = UUID(),
        weekStartDate: Date,
        weekEndDate: Date,
        averageDosePercent: Double,
        previousWeekAveragePercent: Double? = nil,
        totalListeningTimeSeconds: Double,
        daysWithData: Int,
        daysOverLimit: Int,
        currentStreak: Int,
        bestStreak: Int,
        loudestDayDate: Date? = nil,
        loudestDayDosePercent: Double? = nil,
        quietestDayDate: Date? = nil,
        quietestDayDosePercent: Double? = nil,
        averageLevelDBASPL: Double? = nil
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.averageDosePercent = averageDosePercent
        self.previousWeekAveragePercent = previousWeekAveragePercent
        self.totalListeningTimeSeconds = totalListeningTimeSeconds
        self.daysWithData = daysWithData
        self.daysOverLimit = daysOverLimit
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.loudestDayDate = loudestDayDate
        self.loudestDayDosePercent = loudestDayDosePercent
        self.quietestDayDate = quietestDayDate
        self.quietestDayDosePercent = quietestDayDosePercent
        self.averageLevelDBASPL = averageLevelDBASPL
        self.generatedAt = Date()

        let calendar = Calendar.current
        self.year = calendar.component(.year, from: weekStartDate)
        self.weekOfYear = calendar.component(.weekOfYear, from: weekStartDate)
    }

    // MARK: - Computed Properties

    /// Week-over-week change in dose percentage
    var weekOverWeekChange: Double? {
        guard let previous = previousWeekAveragePercent else { return nil }
        return averageDosePercent - previous
    }

    /// Formatted total listening time
    var formattedTotalTime: String {
        let hours = Int(totalListeningTimeSeconds) / 3600
        let minutes = (Int(totalListeningTimeSeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Date range string for display
    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: weekStartDate)
        let end = formatter.string(from: weekEndDate)

        return "\(start) - \(end)"
    }

    /// Status for the week based on average dose
    var weekStatus: ExposureStatus {
        ExposureStatus.from(dosePercent: averageDosePercent)
    }

    /// Comparison indicator
    var comparisonIndicator: String {
        guard let change = weekOverWeekChange else { return "" }
        if change > 5 {
            return "Increased"
        } else if change < -5 {
            return "Decreased"
        } else {
            return "Stable"
        }
    }
}
