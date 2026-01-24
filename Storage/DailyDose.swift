import Foundation
import SwiftData

/// Cached daily dose calculation
@Model
final class DailyDose {
    var date: Date // Start of day
    var dosePercent: Double
    var totalExposureSeconds: Double
    var averageLevelDBASPL: Double?
    var peakLevelDBASPL: Double?
    var lastUpdated: Date

    init(
        date: Date,
        dosePercent: Double = 0,
        totalExposureSeconds: Double = 0,
        averageLevelDBASPL: Double? = nil,
        peakLevelDBASPL: Double? = nil
    ) {
        let calendar = Calendar.current
        self.date = calendar.startOfDay(for: date)
        self.dosePercent = dosePercent
        self.totalExposureSeconds = totalExposureSeconds
        self.averageLevelDBASPL = averageLevelDBASPL
        self.peakLevelDBASPL = peakLevelDBASPL
        self.lastUpdated = Date()
    }

    var status: ExposureStatus {
        ExposureStatus.from(dosePercent: dosePercent)
    }
}
