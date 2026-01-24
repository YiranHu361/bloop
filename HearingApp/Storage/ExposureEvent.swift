import Foundation
import SwiftData

/// Normalized exposure event from HealthKit HKCategorySample
@Model
final class ExposureEvent {
    /// HealthKit sample UUID as string (prevents duplicates)
    @Attribute(.unique) var healthKitUUID: String
    var startDate: Date
    var endDate: Date
    var eventLevelDBASPL: Double?
    var eventDurationSeconds: Double?
    var sourceBundleId: String?
    var sourceName: String?
    
    init(
        healthKitUUID: String,
        startDate: Date,
        endDate: Date,
        eventLevelDBASPL: Double? = nil,
        eventDurationSeconds: Double? = nil,
        sourceBundleId: String? = nil,
        sourceName: String? = nil
    ) {
        self.healthKitUUID = healthKitUUID
        self.startDate = startDate
        self.endDate = endDate
        self.eventLevelDBASPL = eventLevelDBASPL
        self.eventDurationSeconds = eventDurationSeconds
        self.sourceBundleId = sourceBundleId
        self.sourceName = sourceName
    }
}
