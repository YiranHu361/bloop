import Foundation
import HealthKit
import SwiftData
import WidgetKit

/// Manages syncing HealthKit data to local storage with deduplication
@MainActor
final class HealthKitSyncService: ObservableObject {
    static let shared = HealthKitSyncService()

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?

    private var modelContext: ModelContext?
    private var liveQuery: HKAnchoredObjectQuery?
    private let healthStore = HKHealthStore()

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func performFullSync(days: Int = 30) async throws {
        guard let context = modelContext else { return }

        isSyncing = true
        defer { isSyncing = false }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else { return }

        let samples = try await HealthKitService.shared.fetchExposureSamples(from: startDate, to: endDate)

        var insertedCount = 0
        for sample in samples {
            let hkUUID = sample.uuid.uuidString

            let predicate = #Predicate<ExposureSample> { s in
                s.healthKitUUID == hkUUID
            }
            let descriptor = FetchDescriptor<ExposureSample>(predicate: predicate)
            let existing = try context.fetch(descriptor)

            if existing.isEmpty {
                let exposureSample = ExposureSample(
                    healthKitUUID: hkUUID,
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    levelDBASPL: HealthKitService.decibels(from: sample),
                    sourceBundleId: sample.sourceRevision.source.bundleIdentifier,
                    sourceName: sample.sourceRevision.source.name,
                    deviceName: sample.device?.name,
                    isCalibrated: HealthKitService.isCalibrated(sample: sample)
                )
                context.insert(exposureSample)
                insertedCount += 1
            }
        }

        try context.save()
        try await recalculateDailyDoses(from: startDate, to: endDate)

        lastSyncDate = Date()
    }

    func startLiveUpdates() {
        guard let exposureType = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }

        stopLiveUpdates()

        let query = HKAnchoredObjectQuery(
            type: exposureType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, error in
            Task { @MainActor [weak self] in
                await self?.handleLiveUpdate(samples: samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, error in
            Task { @MainActor [weak self] in
                await self?.handleLiveUpdate(samples: samples)
            }
        }

        liveQuery = query
        healthStore.execute(query)
    }

    func stopLiveUpdates() {
        if let query = liveQuery {
            healthStore.stop(query)
            liveQuery = nil
        }
    }

    private func handleLiveUpdate(samples: [HKSample]?) async {
        guard let context = modelContext,
              let quantitySamples = samples as? [HKQuantitySample],
              !quantitySamples.isEmpty else { return }

        let calendar = Calendar.current
        var affectedDates = Set<Date>()
        var insertedCount = 0

        for sample in quantitySamples {
            let hkUUID = sample.uuid.uuidString

            let predicate = #Predicate<ExposureSample> { s in
                s.healthKitUUID == hkUUID
            }
            let descriptor = FetchDescriptor<ExposureSample>(predicate: predicate)

            do {
                let existing = try context.fetch(descriptor)
                if existing.isEmpty {
                    let exposureSample = ExposureSample(
                        healthKitUUID: hkUUID,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        levelDBASPL: HealthKitService.decibels(from: sample),
                        sourceBundleId: sample.sourceRevision.source.bundleIdentifier,
                        sourceName: sample.sourceRevision.source.name,
                        deviceName: sample.device?.name,
                        isCalibrated: HealthKitService.isCalibrated(sample: sample)
                    )
                    context.insert(exposureSample)
                    affectedDates.insert(calendar.startOfDay(for: sample.startDate))
                    insertedCount += 1
                }
            } catch {
                print("Live update error: \(error)")
            }
        }

        if insertedCount > 0 {
            do {
                try context.save()
                for date in affectedDates {
                    try await recalculateDailyDose(for: date)
                }
                lastSyncDate = Date()
                NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)
            } catch {
                print("Live update save error: \(error)")
            }
        }
    }

    private func recalculateDailyDoses(from startDate: Date, to endDate: Date) async throws {
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while currentDate <= endDay {
            try await recalculateDailyDose(for: currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
    }

    func recalculateDailyDose(for date: Date) async throws {
        guard let context = modelContext else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let samplePredicate = #Predicate<ExposureSample> { sample in
            sample.startDate >= startOfDay && sample.startDate < endOfDay
        }

        let sampleDescriptor = FetchDescriptor<ExposureSample>(predicate: samplePredicate)
        let samples = try context.fetch(sampleDescriptor)

        let calculator = DoseCalculator(model: .niosh)
        let result = calculator.calculateDailyDose(from: samples)

        let components = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        guard let year = components.year, let month = components.month, let day = components.day else { return }

        let dosePredicate = #Predicate<DailyDose> { dose in
            dose.year == year && dose.month == month && dose.day == day
        }

        let doseDescriptor = FetchDescriptor<DailyDose>(predicate: dosePredicate)
        let existingDoses = try context.fetch(doseDescriptor)

        if let existingDose = existingDoses.first {
            existingDose.dosePercent = result.dosePercent
            existingDose.totalExposureSeconds = result.totalExposureSeconds
            existingDose.averageLevelDBASPL = result.averageLevel
            existingDose.peakLevelDBASPL = result.peakLevel
            existingDose.timeAbove85dB = result.timeAbove85dB
            existingDose.timeAbove90dB = result.timeAbove90dB
            existingDose.lastUpdated = Date()
        } else {
            let dailyDose = DailyDose(
                date: startOfDay,
                dosePercent: result.dosePercent,
                totalExposureSeconds: result.totalExposureSeconds,
                averageLevelDBASPL: result.averageLevel,
                peakLevelDBASPL: result.peakLevel,
                timeAbove85dB: result.timeAbove85dB,
                timeAbove90dB: result.timeAbove90dB
            )
            context.insert(dailyDose)
        }

        try context.save()
    }
}
