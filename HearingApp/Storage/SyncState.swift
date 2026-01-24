import Foundation
import SwiftData

/// Tracks HealthKit sync state for incremental updates
@Model
final class SyncState {
    @Attribute(.unique) var id: String // Type identifier
    var anchorData: Data?
    var lastSyncDate: Date?
    
    init(id: String, anchorData: Data? = nil, lastSyncDate: Date? = nil) {
        self.id = id
        self.anchorData = anchorData
        self.lastSyncDate = lastSyncDate
    }
}

extension SyncState {
    static let exposureSamplesId = "headphone_audio_exposure_samples"
    static let exposureEventsId = "headphone_audio_exposure_events"
}
