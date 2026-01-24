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
    @Published var sampleCount: Int = 0
    
    private var modelContext: ModelContext?
    private var liveSampleQuery: HKAnchoredObjectQuery?
    private var liveEventQuery: HKAnchoredObjectQuery?
    private let healthStore = HKHealthStore()
    private var currentDoseModel: DoseModel = .niosh

    private init() {}

    /// Set the dose model to use for calculations
    func setDoseModel(_ model: DoseModel) {
        self.currentDoseModel = model
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Reset & Full Resync
    
    /// Clear all local data and resync from HealthKit (fixes duplicate issues)
    func resetAndResync(days: Int = 30) async throws {
        guard let context = modelContext else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("🔄 Starting full reset and resync...")
        
        // Delete all existing samples
        try context.delete(model: ExposureSample.self)
        try context.delete(model: ExposureEvent.self)
        try context.delete(model: DailyDose.self)
        try context.delete(model: SyncState.self)
        try context.save()
        
        print("🗑️ Cleared all local data")
        
        // Perform fresh sync
        try await performFullSync(days: days)
        
        print("✅ Reset and resync complete")
    }
    
    // MARK: - Full Sync
    
    /// Perform a full sync of the last N days (uses upsert to prevent duplicates)
    func performFullSync(days: Int = 30) async throws {
        guard let context = modelContext else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return
        }
        
        // Fetch samples from HealthKit
        let samples = try await HealthKitService.shared.fetchExposureSamples(
            from: startDate,
            to: endDate
        )
        
        // Fetch events from HealthKit
        let events = try await HealthKitService.shared.fetchExposureEvents(
            from: startDate,
            to: endDate
        )
        
        print("📥 Fetched \(samples.count) samples and \(events.count) events from HealthKit")

        // OPTIMIZATION: Batch fetch existing UUIDs upfront to avoid N+1 queries
        var existingSampleUUIDs = Set<String>()
        do {
            let allSamplesDescriptor = FetchDescriptor<ExposureSample>()
            let allSamples = try context.fetch(allSamplesDescriptor)
            existingSampleUUIDs = Set(allSamples.map { $0.healthKitUUID })
        } catch {
            print("Error fetching existing sample UUIDs: \(error)")
        }

        // Upsert samples with fast in-memory deduplication
        var insertedCount = 0
        for sample in samples {
            let hkUUID = sample.uuid.uuidString

            if !existingSampleUUIDs.contains(hkUUID) {
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
                existingSampleUUIDs.insert(hkUUID)
            }
        }

        // Batch fetch existing event UUIDs
        var existingEventUUIDs = Set<String>()
        do {
            let allEventsDescriptor = FetchDescriptor<ExposureEvent>()
            let allEvents = try context.fetch(allEventsDescriptor)
            existingEventUUIDs = Set(allEvents.map { $0.healthKitUUID })
        } catch {
            print("Error fetching existing event UUIDs: \(error)")
        }

        // Upsert events with fast in-memory deduplication
        for event in events {
            let hkUUID = event.uuid.uuidString

            if !existingEventUUIDs.contains(hkUUID) {
                let metadata = HealthKitService.eventMetadata(from: event)
                let exposureEvent = ExposureEvent(
                    healthKitUUID: hkUUID,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    eventLevelDBASPL: metadata.level,
                    eventDurationSeconds: metadata.duration,
                    sourceBundleId: event.sourceRevision.source.bundleIdentifier,
                    sourceName: event.sourceRevision.source.name
                )
                context.insert(exposureEvent)
                existingEventUUIDs.insert(hkUUID)
            }
        }
        
        try context.save()
        print("💾 Inserted \(insertedCount) new samples (skipped duplicates)")
        
        // Recalculate daily doses
        try await recalculateDailyDoses(from: startDate, to: endDate)
        
        lastSyncDate = Date()
        sampleCount = samples.count
    }
    
    // MARK: - Incremental Sync (with deduplication)
    
    /// Perform incremental sync using anchored queries
    func performIncrementalSync() async throws {
        guard let context = modelContext else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // Get stored anchors
        let sampleAnchor = try getSyncAnchor(for: SyncState.exposureSamplesId)
        let eventAnchor = try getSyncAnchor(for: SyncState.exposureEventsId)
        
        // Fetch new samples
        let (newSamples, newSampleAnchor) = try await HealthKitService.shared.fetchNewExposureSamples(
            anchor: sampleAnchor
        )
        
        // Fetch new events
        let (newEvents, newEventAnchor) = try await HealthKitService.shared.fetchNewExposureEvents(
            anchor: eventAnchor
        )
        
        // OPTIMIZATION: Batch fetch existing UUIDs to avoid N+1 queries
        var affectedDates = Set<Date>()
        let calendar = Calendar.current
        var insertedCount = 0

        // Batch fetch all existing sample UUIDs
        var existingSampleUUIDs = Set<String>()
        do {
            let allSamplesDescriptor = FetchDescriptor<ExposureSample>()
            let allSamples = try context.fetch(allSamplesDescriptor)
            existingSampleUUIDs = Set(allSamples.map { $0.healthKitUUID })
        } catch {
            print("Error fetching existing sample UUIDs: \(error)")
        }

        // Process new samples with fast in-memory deduplication
        for sample in newSamples {
            let hkUUID = sample.uuid.uuidString

            if !existingSampleUUIDs.contains(hkUUID) {
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
                existingSampleUUIDs.insert(hkUUID)
            }
        }

        // Batch fetch all existing event UUIDs
        var existingEventUUIDs = Set<String>()
        do {
            let allEventsDescriptor = FetchDescriptor<ExposureEvent>()
            let allEvents = try context.fetch(allEventsDescriptor)
            existingEventUUIDs = Set(allEvents.map { $0.healthKitUUID })
        } catch {
            print("Error fetching existing event UUIDs: \(error)")
        }

        // Process new events with fast in-memory deduplication
        for event in newEvents {
            let hkUUID = event.uuid.uuidString

            if !existingEventUUIDs.contains(hkUUID) {
                let metadata = HealthKitService.eventMetadata(from: event)
                let exposureEvent = ExposureEvent(
                    healthKitUUID: hkUUID,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    eventLevelDBASPL: metadata.level,
                    eventDurationSeconds: metadata.duration,
                    sourceBundleId: event.sourceRevision.source.bundleIdentifier,
                    sourceName: event.sourceRevision.source.name
                )
                context.insert(exposureEvent)
                existingEventUUIDs.insert(hkUUID)
            }
        }
        
        // Save anchors
        if let newSampleAnchor = newSampleAnchor {
            try saveSyncAnchor(newSampleAnchor, for: SyncState.exposureSamplesId)
        }
        if let newEventAnchor = newEventAnchor {
            try saveSyncAnchor(newEventAnchor, for: SyncState.exposureEventsId)
        }
        
        try context.save()
        
        if insertedCount > 0 {
            print("📥 Incremental sync: inserted \(insertedCount) new samples")
        }
        
        // Recalculate affected daily doses
        for date in affectedDates {
            try await recalculateDailyDose(for: date)
        }
        
        lastSyncDate = Date()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)
        
        // Check if notifications should be sent
        await checkAndSendNotifications()
    }
    
    // MARK: - Live Streaming Query (Real-time updates)
    
    /// Start live anchored queries that stream updates as they arrive
    func startLiveUpdates() {
        // Stop existing queries if any
        stopLiveUpdates()

        // Start sample query
        if let exposureType = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) {
            let sampleAnchor: HKQueryAnchor?
            do {
                sampleAnchor = try getSyncAnchor(for: SyncState.exposureSamplesId)
            } catch {
                sampleAnchor = nil
            }

            let sampleQuery = HKAnchoredObjectQuery(
                type: exposureType,
                predicate: nil,
                anchor: sampleAnchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] query, samples, deleted, newAnchor, error in
                if let error = error {
                    print("⚠️ Live sample query error: \(error)")
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.handleLiveUpdate(samples: samples, newAnchor: newAnchor)
                }
            }

            sampleQuery.updateHandler = { [weak self] query, samples, deleted, newAnchor, error in
                if let error = error {
                    print("⚠️ Live sample update error: \(error)")
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.handleLiveUpdate(samples: samples, newAnchor: newAnchor)
                }
            }

            liveSampleQuery = sampleQuery
            healthStore.execute(sampleQuery)
        }

        // Start event query
        if let eventType = HKCategoryType.categoryType(forIdentifier: .headphoneAudioExposureEvent) {
            let eventAnchor: HKQueryAnchor?
            do {
                eventAnchor = try getSyncAnchor(for: SyncState.exposureEventsId)
            } catch {
                eventAnchor = nil
            }

            let eventQuery = HKAnchoredObjectQuery(
                type: eventType,
                predicate: nil,
                anchor: eventAnchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] query, events, deleted, newAnchor, error in
                if let error = error {
                    print("⚠️ Live event query error: \(error)")
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.handleLiveEventUpdate(events: events, newAnchor: newAnchor)
                }
            }

            eventQuery.updateHandler = { [weak self] query, events, deleted, newAnchor, error in
                if let error = error {
                    print("⚠️ Live event update error: \(error)")
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.handleLiveEventUpdate(events: events, newAnchor: newAnchor)
                }
            }

            liveEventQuery = eventQuery
            healthStore.execute(eventQuery)
        }

        print("🎧 Started live HealthKit streaming (samples + events)")
    }

    /// Stop live streaming
    func stopLiveUpdates() {
        if let query = liveSampleQuery {
            healthStore.stop(query)
            liveSampleQuery = nil
        }
        if let query = liveEventQuery {
            healthStore.stop(query)
            liveEventQuery = nil
        }
    }

    private func handleLiveEventUpdate(events: [HKSample]?, newAnchor: HKQueryAnchor?) async {
        guard let context = modelContext else { return }

        // Save anchor
        if let newAnchor = newAnchor {
            do {
                try saveSyncAnchor(newAnchor, for: SyncState.exposureEventsId)
            } catch {
                print("Event anchor save error: \(error)")
            }
        }

        guard let categoryEvents = events as? [HKCategorySample],
              !categoryEvents.isEmpty else {
            return
        }

        var insertedCount = 0

        // OPTIMIZATION: Batch fetch existing UUIDs
        var existingUUIDs = Set<String>()
        do {
            let allEventsDescriptor = FetchDescriptor<ExposureEvent>()
            let allEvents = try context.fetch(allEventsDescriptor)
            existingUUIDs = Set(allEvents.map { $0.healthKitUUID })
        } catch {
            print("Error fetching existing events: \(error)")
        }

        for event in categoryEvents {
            let hkUUID = event.uuid.uuidString

            // Fast in-memory check
            if !existingUUIDs.contains(hkUUID) {
                let metadata = HealthKitService.eventMetadata(from: event)
                let exposureEvent = ExposureEvent(
                    healthKitUUID: hkUUID,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    eventLevelDBASPL: metadata.level,
                    eventDurationSeconds: metadata.duration,
                    sourceBundleId: event.sourceRevision.source.bundleIdentifier,
                    sourceName: event.sourceRevision.source.name
                )
                context.insert(exposureEvent)
                insertedCount += 1
                existingUUIDs.insert(hkUUID)
            }
        }

        do {
            try context.save()
            NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)

            if insertedCount > 0 {
                print("⚡️ Live event update: \(insertedCount) new events")
            }
        } catch {
            print("Live event save error: \(error)")
        }
    }
    
    private func handleLiveUpdate(samples: [HKSample]?, newAnchor: HKQueryAnchor?) async {
        guard let context = modelContext else { return }

        // Always save anchor even if no new samples (to maintain sync state)
        if let newAnchor = newAnchor {
            do {
                try saveSyncAnchor(newAnchor, for: SyncState.exposureSamplesId)
            } catch {
                print("Anchor save error: \(error)")
            }
        }

        // Always notify UI even if no new samples (keeps "last updated" fresh)
        guard let quantitySamples = samples as? [HKQuantitySample],
              !quantitySamples.isEmpty else {
            // Post notification anyway so UI updates timestamp
            NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)
            return
        }

        print("🎧 Received \(quantitySamples.count) samples from HealthKit")

        let calendar = Calendar.current
        var affectedDates = Set<Date>()
        var insertedCount = 0

        // OPTIMIZATION: Batch fetch existing UUIDs to avoid N+1 queries
        let incomingUUIDs = Set(quantitySamples.map { $0.uuid.uuidString })
        var existingUUIDs = Set<String>()

        do {
            // Fetch all samples and check UUIDs in memory (faster than N individual queries)
            let allSamplesDescriptor = FetchDescriptor<ExposureSample>()
            let allSamples = try context.fetch(allSamplesDescriptor)
            existingUUIDs = Set(allSamples.map { $0.healthKitUUID })
        } catch {
            print("Error fetching existing samples: \(error)")
        }

        for sample in quantitySamples {
            let hkUUID = sample.uuid.uuidString

            // Fast in-memory check instead of database query
            if !existingUUIDs.contains(hkUUID) {
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
                existingUUIDs.insert(hkUUID)  // Track newly inserted
            }
        }

        do {
            try context.save()

            // Recalculate affected daily doses
            for date in affectedDates {
                try await recalculateDailyDose(for: date)
            }

            lastSyncDate = Date()

            // Always post notification when we receive samples
            // This ensures UI stays in sync with real-time updates
            NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)

            if insertedCount > 0 {
                print("⚡️ Live update: \(insertedCount) new samples")
            }
        } catch {
            print("Live update save error: \(error)")
        }
    }
    
    // MARK: - Daily Dose Calculation
    
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
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }
        
        // Fetch samples for this day
        let samplePredicate = #Predicate<ExposureSample> { sample in
            sample.startDate >= startOfDay && sample.startDate < endOfDay
        }
        
        let sampleDescriptor = FetchDescriptor<ExposureSample>(predicate: samplePredicate)
        let samples = try context.fetch(sampleDescriptor)
        
        // Calculate dose using DoseCalculator
        let calculator = DoseCalculator(model: currentDoseModel)
        let result = calculator.calculateDailyDose(from: samples)
        
        // Find or create daily dose record
        let components = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return
        }
        let dosePredicate = #Predicate<DailyDose> { dose in
            dose.year == year &&
            dose.month == month &&
            dose.day == day
        }
        
        let doseDescriptor = FetchDescriptor<DailyDose>(predicate: dosePredicate)
        let existingDoses = try context.fetch(doseDescriptor)
        
        if let existingDose = existingDoses.first {
            // Update existing
            existingDose.dosePercent = result.dosePercent
            existingDose.totalExposureSeconds = result.totalExposureSeconds
            existingDose.averageLevelDBASPL = result.averageLevel
            existingDose.peakLevelDBASPL = result.peakLevel
            existingDose.timeAbove85dB = result.timeAbove85dB
            existingDose.timeAbove90dB = result.timeAbove90dB
            existingDose.lastUpdated = Date()
        } else {
            // Create new
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
    
    // MARK: - Anchor Management
    
    private func getSyncAnchor(for id: String) throws -> HKQueryAnchor? {
        guard let context = modelContext else { return nil }
        
        let predicate = #Predicate<SyncState> { state in
            state.id == id
        }
        
        let descriptor = FetchDescriptor<SyncState>(predicate: predicate)
        let states = try context.fetch(descriptor)
        
        guard let anchorData = states.first?.anchorData else { return nil }
        
        return try NSKeyedUnarchiver.unarchivedObject(
            ofClass: HKQueryAnchor.self,
            from: anchorData
        )
    }
    
    private func saveSyncAnchor(_ anchor: HKQueryAnchor, for id: String) throws {
        guard let context = modelContext else { return }
        
        let anchorData = try NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        )
        
        let predicate = #Predicate<SyncState> { state in
            state.id == id
        }
        
        let descriptor = FetchDescriptor<SyncState>(predicate: predicate)
        let states = try context.fetch(descriptor)
        
        if let existing = states.first {
            existing.anchorData = anchorData
            existing.lastSyncDate = Date()
        } else {
            let newState = SyncState(id: id, anchorData: anchorData, lastSyncDate: Date())
            context.insert(newState)
        }
        
        try context.save()
    }
    
    // MARK: - Notifications

    private func checkAndSendNotifications() async {
        guard let context = modelContext else { return }

        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let components = calendar.dateComponents([.year, .month, .day], from: today)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return
            }

            let predicate = #Predicate<DailyDose> { dose in
                dose.year == year &&
                dose.month == month &&
                dose.day == day
            }

            let descriptor = FetchDescriptor<DailyDose>(predicate: predicate)
            let doses = try context.fetch(descriptor)

            if let todayDose = doses.first {
                // Send threshold notifications
                await NotificationService.shared.checkAndNotify(for: todayDose.dosePercent)

                // Update widget data
                updateWidgetData(dose: todayDose)
            }
        } catch {
            print("Error checking notifications: \(error)")
        }
    }

    // MARK: - Widget Integration

    private func updateWidgetData(dose: DailyDose) {
        let appGroupIdentifier = "group.com.bloopapp.shared"

        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        // Calculate remaining time
        let calculator = DoseCalculator(model: .niosh)
        let level = dose.averageLevelDBASPL ?? 80.0
        let remainingTime = calculator.remainingSafeTime(currentDosePercent: dose.dosePercent, at: level)

        defaults.set(dose.dosePercent, forKey: "widget_dosePercent")
        defaults.set(remainingTime, forKey: "widget_remainingTime")
        defaults.set(Date(), forKey: "widget_lastUpdate")

        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "BloopWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "BloopWidgetLockScreen")
    }
}
