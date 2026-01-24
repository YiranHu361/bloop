import Foundation
import HealthKit
import SwiftData

/// HealthKit service for fetching headphone audio exposure data
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    @Published var isAuthorized: Bool = false

    private init() {}

    private var headphoneAudioExposureType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure)
    }

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

    func fetchAndStoreSamples(context: ModelContext, days: Int) async throws {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else { return }

        let hkSamples = try await fetchExposureSamples(from: startDate, to: endDate)

        for sample in hkSamples {
            let dbLevel = sample.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
            let exposureSample = ExposureSample(
                startDate: sample.startDate,
                endDate: sample.endDate,
                levelDBASPL: dbLevel,
                sourceBundleId: sample.sourceRevision.source.bundleIdentifier
            )
            context.insert(exposureSample)
        }

        try context.save()
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case typesNotAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available"
        case .typesNotAvailable: return "Required types not available"
        }
    }
}
