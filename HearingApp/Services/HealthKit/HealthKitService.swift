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

    private var headphoneAudioExposureType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure)
    }

    private var headphoneAudioExposureEventType: HKCategoryType? {
        HKCategoryType.categoryType(forIdentifier: .headphoneAudioExposureEvent)
    }

    private var typesToRead: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let exposureType = headphoneAudioExposureType { types.insert(exposureType) }
        if let eventType = headphoneAudioExposureEventType { types.insert(eventType) }
        return types
    }

    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            authorizationStatus = .unavailable
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)

        if let exposureType = headphoneAudioExposureType {
            let status = healthStore.authorizationStatus(for: exposureType)
            switch status {
            case .sharingAuthorized: authorizationStatus = .authorized
            case .sharingDenied: authorizationStatus = .denied
            default: authorizationStatus = .notDetermined
            }
        }
    }

    func checkAuthorizationStatus() -> HealthKitAuthorizationStatus {
        guard isHealthKitAvailable else { return .unavailable }
        return authorizationStatus
    }

    func fetchExposureSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        guard let exposureType = headphoneAudioExposureType else {
            throw HealthKitError.typesNotAvailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

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
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    func enableBackgroundDelivery() {
        guard let exposureType = headphoneAudioExposureType else { return }
        healthStore.enableBackgroundDelivery(for: exposureType, frequency: .immediate) { _, error in
            if let error = error {
                print("Failed to enable background delivery: \(error)")
            }
        }
    }

    static func decibels(from sample: HKQuantitySample) -> Double {
        sample.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
    }

    static func isCalibrated(sample: HKSample) -> Bool {
        guard let device = sample.device else { return false }
        let name = device.name?.lowercased() ?? ""
        return name.contains("airpod") || name.contains("beats") || name.contains("apple")
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case typesNotAvailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device"
        case .typesNotAvailable: return "Required HealthKit types are not available"
        case .authorizationDenied: return "HealthKit authorization was denied"
        }
    }
}

extension Notification.Name {
    static let healthKitDataUpdated = Notification.Name("healthKitDataUpdated")
}
