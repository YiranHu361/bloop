import Foundation
import SwiftData

/// Cached daily dose calculation
@Model
final class DailyDose {
    @Attribute(.unique) var date: Date // Start of day
    var dosePercent: Double
    var totalExposureSeconds: Double
    var averageLevelDBASPL: Double?
    var peakLevelDBASPL: Double?
    var timeAbove85dB: Double // seconds
    var timeAbove90dB: Double // seconds
    var lastUpdated: Date
    
    /// Calendar date components for easier querying
    var year: Int
    var month: Int
    var day: Int
    
    init(
        date: Date,
        dosePercent: Double = 0,
        totalExposureSeconds: Double = 0,
        averageLevelDBASPL: Double? = nil,
        peakLevelDBASPL: Double? = nil,
        timeAbove85dB: Double = 0,
        timeAbove90dB: Double = 0
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        self.date = startOfDay
        self.dosePercent = dosePercent
        self.totalExposureSeconds = totalExposureSeconds
        self.averageLevelDBASPL = averageLevelDBASPL
        self.peakLevelDBASPL = peakLevelDBASPL
        self.timeAbove85dB = timeAbove85dB
        self.timeAbove90dB = timeAbove90dB
        self.lastUpdated = Date()
        
        let components = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        self.year = components.year ?? 0
        self.month = components.month ?? 0
        self.day = components.day ?? 0
    }
    
    var status: ExposureStatus {
        ExposureStatus.from(dosePercent: dosePercent)
    }
    
    var formattedExposureTime: String {
        let hours = Int(totalExposureSeconds) / 3600
        let minutes = (Int(totalExposureSeconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
