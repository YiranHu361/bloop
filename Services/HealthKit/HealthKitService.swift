import Foundation
import HealthKit

/// Basic HealthKit service - prototype version
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    @Published var isAuthorized: Bool = false

    private init() {}

    // MARK: - Types

    private var headphoneAudioExposureType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure)
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        guard let exposureType = headphoneAudioExposureType else {
            throw HealthKitError.typesNotAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: [exposureType])
        isAuthorized = true
    }

    // MARK: - Data Fetching

    func fetchExposureSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        guard let exposureType = headphoneAudioExposureType else {
            throw HealthKitError.typesNotAvailable
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: exposureType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
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
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case typesNotAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available"
        case .typesNotAvailable:
            return "Required types not available"
        }
    }
}
