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
    private var liveQuery: HKAnchoredObjectQuery?
    private let healthStore = HKHealthStore()
    
    private init() {}
    
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
        
        // Upsert samples (using HealthKit UUID prevents duplicates)
        var insertedCount = 0
        for sample in samples {
            let hkUUID = sample.uuid.uuidString
            
            // Check if already exists
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
        
        // Upsert events
        for event in events {
            let hkUUID = event.uuid.uuidString
            
            let predicate = #Predicate<ExposureEvent> { e in
                e.healthKitUUID == hkUUID
            }
            let descriptor = FetchDescriptor<ExposureEvent>(predicate: predicate)
            let existing = try context.fetch(descriptor)
            
            if existing.isEmpty {
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
        
        // Process new samples with deduplication
        var affectedDates = Set<Date>()
        let calendar = Calendar.current
        var insertedCount = 0
        
        for sample in newSamples {
            let hkUUID = sample.uuid.uuidString
            
            // Check if already exists
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
                affectedDates.insert(calendar.startOfDay(for: sample.startDate))
                insertedCount += 1
            }
        }
        
        // Process new events with deduplication
        for event in newEvents {
            let hkUUID = event.uuid.uuidString
            
            let predicate = #Predicate<ExposureEvent> { e in
                e.healthKitUUID == hkUUID
            }
            let descriptor = FetchDescriptor<ExposureEvent>(predicate: predicate)
            let existing = try context.fetch(descriptor)
            
            if existing.isEmpty {
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
    
    /// Start a live anchored query that streams updates as they arrive
    func startLiveUpdates() {
        guard let exposureType = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) else {
            return
        }
        
        // Stop existing query if any
        stopLiveUpdates()
        
        // Get current anchor
        let anchor: HKQueryAnchor?
        do {
            anchor = try getSyncAnchor(for: SyncState.exposureSamplesId)
        } catch {
            anchor = nil
        }
        
        // Create live anchored query with update handler
        let query = HKAnchoredObjectQuery(
            type: exposureType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, newAnchor, error in
            // Initial results handler
            Task { @MainActor [weak self] in
                await self?.handleLiveUpdate(samples: samples, newAnchor: newAnchor)
            }
        }
        
        // Set update handler for real-time streaming
        query.updateHandler = { [weak self] query, samples, deleted, newAnchor, error in
            Task { @MainActor [weak self] in
                await self?.handleLiveUpdate(samples: samples, newAnchor: newAnchor)
            }
        }
        
        liveQuery = query
        healthStore.execute(query)
        print("🎧 Started live HealthKit streaming")
    }
    
    /// Stop live streaming
    func stopLiveUpdates() {
        if let query = liveQuery {
            healthStore.stop(query)
            liveQuery = nil
            print("⏹️ Stopped live HealthKit streaming")
        }
    }
    
    private func handleLiveUpdate(samples: [HKSample]?, newAnchor: HKQueryAnchor?) async {
        guard let context = modelContext,
              let quantitySamples = samples as? [HKQuantitySample],
              !quantitySamples.isEmpty else {
            return
        }
        
        let calendar = Calendar.current
        var affectedDates = Set<Date>()
        var insertedCount = 0
        var latestSample: HKQuantitySample?
        
        for sample in quantitySamples {
            let hkUUID = sample.uuid.uuidString
            
            // Check if already exists
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
                    
                    // Track the most recent sample for Live Activity notification
                    if latestSample == nil || sample.endDate > latestSample!.endDate {
                        latestSample = sample
                    }
                }
            } catch {
                print("Live update error: \(error)")
            }
        }
        
        if insertedCount > 0 {
            do {
                // Save anchor
                if let newAnchor = newAnchor {
                    try saveSyncAnchor(newAnchor, for: SyncState.exposureSamplesId)
                }
                
                try context.save()
                
                // Recalculate affected daily doses
                for date in affectedDates {
                    try await recalculateDailyDose(for: date)
                }
                
                lastSyncDate = Date()
                
                // Post notification for immediate UI update
                NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)
                
                // Notify LiveSessionCoordinator about the new sample for Live Activity
                if let sample = latestSample {
                    let payload = ExposureSamplePayload(
                        timestamp: sample.endDate,
                        levelDBASPL: HealthKitService.decibels(from: sample),
                        durationSeconds: sample.endDate.timeIntervalSince(sample.startDate)
                    )
                    NotificationCenter.default.post(
                        name: .exposureSampleArrived,
                        object: payload
                    )
                }
                
                print("⚡️ Live update: \(insertedCount) new samples")
            } catch {
                print("Live update save error: \(error)")
            }
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
        let calculator = DoseCalculator(model: .niosh)
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
                // Send notifications using the new unified API
                // This handles threshold alerts, volume alerts, and Live Activity updates
                await NotificationService.shared.checkAndNotify(
                    dosePercent: todayDose.dosePercent,
                    currentDB: todayDose.averageLevelDBASPL.map { Int($0) }
                )

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
        defaults.set(dose.totalExposureSeconds, forKey: "widget_listeningTime")
        defaults.set(Date(), forKey: "widget_lastUpdate")

        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "BloopWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "BloopWidgetLockScreen")
    }
}
