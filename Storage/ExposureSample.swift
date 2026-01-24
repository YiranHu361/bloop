import Foundation
import SwiftData

/// Exposure sample from HealthKit
@Model
final class ExposureSample {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var levelDBASPL: Double

    /// Duration in seconds
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        levelDBASPL: Double
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.levelDBASPL = levelDBASPL
    }
}
