import Foundation
import SwiftData

/// Normalized exposure sample from HealthKit HKQuantitySample
@Model
final class ExposureSample {
    /// HealthKit sample UUID as string (prevents duplicates)
    @Attribute(.unique) var healthKitUUID: String
    var startDate: Date
    var endDate: Date
    var levelDBASPL: Double
    var sourceBundleId: String?
    var sourceName: String?
    var deviceName: String?
    var isCalibrated: Bool
    
    /// Duration in seconds
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    init(
        healthKitUUID: String,
        startDate: Date,
        endDate: Date,
        levelDBASPL: Double,
        sourceBundleId: String? = nil,
        sourceName: String? = nil,
        deviceName: String? = nil,
        isCalibrated: Bool = false
    ) {
        self.healthKitUUID = healthKitUUID
        self.startDate = startDate
        self.endDate = endDate
        self.levelDBASPL = levelDBASPL
        self.sourceBundleId = sourceBundleId
        self.sourceName = sourceName
        self.deviceName = deviceName
        self.isCalibrated = isCalibrated
    }
}

extension ExposureSample {
    /// Check if sample is from Apple headphones (AirPods, Beats)
    var isFromAppleHeadphones: Bool {
        guard let device = deviceName?.lowercased() else { return false }
        return device.contains("airpod") || device.contains("beats") || device.contains("apple")
    }
}
