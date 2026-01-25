import Foundation
import HealthKit
import SwiftData

/// Service for interacting with HealthKit headphone audio exposure data
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    
    @Published var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    @Published var isHealthKitAvailable: Bool = false
    
    private init() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Types we need
    
    private var headphoneAudioExposureType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure)
    }
    
    private var headphoneAudioExposureEventType: HKCategoryType? {
        HKCategoryType.categoryType(forIdentifier: .headphoneAudioExposureEvent)
    }
    
    private var typesToRead: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let exposureType = headphoneAudioExposureType {
            types.insert(exposureType)
        }
        if let eventType = headphoneAudioExposureEventType {
            types.insert(eventType)
        }
        return types
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            authorizationStatus = .unavailable
            throw HealthKitError.notAvailable
        }
        
        guard !typesToRead.isEmpty else {
            throw HealthKitError.typesNotAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        // Check authorization status for our types
        if let exposureType = headphoneAudioExposureType {
            let status = healthStore.authorizationStatus(for: exposureType)
            switch status {
            case .sharingAuthorized:
                authorizationStatus = .authorized
            case .sharingDenied:
                authorizationStatus = .denied
            case .notDetermined:
                authorizationStatus = .notDetermined
            @unknown default:
                authorizationStatus = .notDetermined
            }
        }
    }
    
    func checkAuthorizationStatus() -> HealthKitAuthorizationStatus {
        guard isHealthKitAvailable else { return .unavailable }

        // Check if we have the type available and have requested before
        guard let exposureType = headphoneAudioExposureType else {
            return .unavailable
        }

        // For read permissions, we can't definitively know if granted,
        // but we can check if we've been explicitly denied write access
        // or if the type is available for querying
        let status = healthStore.authorizationStatus(for: exposureType)
        switch status {
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            // Note: This only reflects write permission status
            // For read-only, we should try to query
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    /// Check if we can read HealthKit data by attempting a test query
    func canReadHealthKitData() async -> Bool {
        guard isHealthKitAvailable,
              let exposureType = headphoneAudioExposureType else {
            return false
        }

        // Try a simple query to see if we have read access
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: exposureType,
                predicate: nil,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                // If we get samples or nil error, we have access
                // If error is authorization error, we don't
                if let error = error as? HKError, error.code == .errorAuthorizationDenied {
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Data Fetching
    
    /// Fetch headphone audio exposure samples for a date range
    func fetchExposureSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        guard let exposureType = headphoneAudioExposureType else {
            throw HealthKitError.typesNotAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: exposureType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: quantitySamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch headphone audio exposure events for a date range
    func fetchExposureEvents(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKCategorySample] {
        guard let eventType = headphoneAudioExposureEventType else {
            throw HealthKitError.typesNotAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: eventType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Anchored Queries (Incremental Sync)
    
    /// Fetch new samples since last anchor
    func fetchNewExposureSamples(
        anchor: HKQueryAnchor?
    ) async throws -> (samples: [HKQuantitySample], newAnchor: HKQueryAnchor?) {
        guard let exposureType = headphoneAudioExposureType else {
            throw HealthKitError.typesNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: exposureType,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, addedSamples, _, newAnchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let samples = (addedSamples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: (samples, newAnchor))
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch new events since last anchor
    func fetchNewExposureEvents(
        anchor: HKQueryAnchor?
    ) async throws -> (events: [HKCategorySample], newAnchor: HKQueryAnchor?) {
        guard let eventType = headphoneAudioExposureEventType else {
            throw HealthKitError.typesNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: eventType,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, addedSamples, _, newAnchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let events = (addedSamples as? [HKCategorySample]) ?? []
                continuation.resume(returning: (events, newAnchor))
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Background Delivery
    
    func enableBackgroundDelivery() {
        guard let exposureType = headphoneAudioExposureType else { return }
        
        healthStore.enableBackgroundDelivery(
            for: exposureType,
            frequency: .immediate
        ) { _, _ in
            // Background delivery callback
        }

        if let eventType = headphoneAudioExposureEventType {
            healthStore.enableBackgroundDelivery(
                for: eventType,
                frequency: .immediate
            ) { _, _ in
                // Background delivery callback
            }
        }
    }
    
    // MARK: - Observer Queries
    
    func startObserving(onUpdate: @escaping () -> Void) {
        // Observe exposure samples
        if let exposureType = headphoneAudioExposureType {
            let sampleQuery = HKObserverQuery(sampleType: exposureType, predicate: nil) { _, completionHandler, error in
                if error == nil {
                    onUpdate()
                }
                completionHandler()
            }
            observerQueries.append(sampleQuery)
            healthStore.execute(sampleQuery)
        }

        // Observe exposure events
        if let eventType = headphoneAudioExposureEventType {
            let eventQuery = HKObserverQuery(sampleType: eventType, predicate: nil) { _, completionHandler, error in
                if error == nil {
                    onUpdate()
                }
                completionHandler()
            }
            observerQueries.append(eventQuery)
            healthStore.execute(eventQuery)
        }
    }
    
    func stopObserving() {
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
    }
    
    // MARK: - Sync Trigger
    
    func syncLatestData() async {
        // This would be called to trigger a full sync
        // Implementation depends on how you want to coordinate with the data layer
        NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)
    }
}

// MARK: - Helper Extensions

extension HealthKitService {
    /// Extract dB level from a quantity sample
    static func decibels(from sample: HKQuantitySample) -> Double {
        let unit = HKUnit.decibelAWeightedSoundPressureLevel()
        return sample.quantity.doubleValue(for: unit)
    }
    
    /// Extract metadata from exposure event
    static func eventMetadata(from sample: HKCategorySample) -> (level: Double?, duration: Double?) {
        let level = sample.metadata?[HKMetadataKeyAudioExposureLevel] as? HKQuantity
        let duration = sample.metadata?[HKMetadataKeyAudioExposureDuration] as? HKQuantity
        
        let levelValue = level?.doubleValue(for: .decibelAWeightedSoundPressureLevel())
        let durationValue = duration?.doubleValue(for: .second())
        
        return (levelValue, durationValue)
    }
    
    /// Check if sample is from a calibrated source (Apple headphones)
    static func isCalibrated(sample: HKSample) -> Bool {
        guard let device = sample.device else { return false }
        let name = device.name?.lowercased() ?? ""
        return name.contains("airpod") || name.contains("beats") || name.contains("apple")
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case typesNotAvailable
    case authorizationDenied
    case queryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .typesNotAvailable:
            return "Required HealthKit types are not available"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .queryFailed(let error):
            return "HealthKit query failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let healthKitDataUpdated = Notification.Name("healthKitDataUpdated")
}
