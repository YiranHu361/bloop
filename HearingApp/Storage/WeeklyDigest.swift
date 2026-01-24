import Foundation
import SwiftData

/// Weekly digest summary
@Model
final class WeeklyDigest {
    @Attribute(.unique) var id: UUID

    var weekStartDate: Date
    var weekEndDate: Date
    var averageDosePercent: Double
    var previousWeekAveragePercent: Double?
    var totalListeningTimeSeconds: Double
    var daysWithData: Int
    var daysOverLimit: Int
    var currentStreak: Int
    var bestStreak: Int
    var loudestDayDate: Date?
    var loudestDayDosePercent: Double?
    var quietestDayDate: Date?
    var quietestDayDosePercent: Double?
    var generatedAt: Date

    var year: Int
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
        quietestDayDosePercent: Double? = nil
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
        self.generatedAt = Date()

        let calendar = Calendar.current
        self.year = calendar.component(.year, from: weekStartDate)
        self.weekOfYear = calendar.component(.weekOfYear, from: weekStartDate)
    }

    var weekOverWeekChange: Double? {
        guard let previous = previousWeekAveragePercent else { return nil }
        return averageDosePercent - previous
    }

    var formattedTotalTime: String {
        let hours = Int(totalListeningTimeSeconds) / 3600
        let minutes = (Int(totalListeningTimeSeconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var weekStatus: ExposureStatus {
        ExposureStatus.from(dosePercent: averageDosePercent)
    }
}
