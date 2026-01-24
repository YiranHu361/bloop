import SwiftUI
import SwiftData

@main
struct BloopApp: App {
    @StateObject private var appState = AppState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ExposureSample.self,
            ExposureEvent.self,
            DailyDose.self,
            UserSettings.self,
            SyncState.self,
            WeeklyDigest.self,
            PersonalizedThreshold.self,
            PersonalizationPreferences.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            if appState.hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appState)
                    .onAppear {
                        setupServices()
                    }
            } else {
                OnboardingView()
                    .environmentObject(appState)
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupServices() {
        Task { @MainActor in
            do {
                // Configure sync service with model context and dose model
                HealthKitSyncService.shared.configure(modelContext: sharedModelContainer.mainContext)
                HealthKitSyncService.shared.setDoseModel(appState.selectedDoseModel)

                // Configure weekly digest scheduler
                WeeklyDigestScheduler.shared.configure(modelContext: sharedModelContainer.mainContext)

                // Configure personalization service
                await PersonalizationService.shared.configure(modelContext: sharedModelContainer.mainContext)

                // Register notification categories
                NotificationService.shared.registerCategories()

                // Schedule weekly digest notification
                await WeeklyDigestScheduler.shared.scheduleWeeklyDigestNotification()

                // Always request authorization (does nothing if already granted)
                try? await HealthKitService.shared.requestAuthorization()

                // Check if we can actually read data (more reliable than checking status)
                let canRead = await HealthKitService.shared.canReadHealthKitData()

                guard canRead else {
                    print("⚠️ Cannot read HealthKit data - authorization may be denied")
                    return
                }

                // Enable background delivery AFTER authorization
                HealthKitService.shared.enableBackgroundDelivery()

                // Start observer query for background delivery callbacks
                HealthKitService.shared.startObserving {
                    // Just post notification - live updates handle actual sync
                    NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)
                }

                // Check if we need to do a full reset (one-time migration to fix duplicates)
                let needsReset = !UserDefaults.standard.bool(forKey: "hasPerformedDataReset_v2")

                if needsReset {
                    print("🔄 Performing one-time data reset to fix duplicates...")
                    try await HealthKitSyncService.shared.resetAndResync(days: 30)
                    UserDefaults.standard.set(true, forKey: "hasPerformedDataReset_v2")
                } else {
                    // Normal incremental sync
                    try await HealthKitSyncService.shared.performIncrementalSync()
                }

                // Start live streaming for real-time updates
                HealthKitSyncService.shared.startLiveUpdates()

                print("✅ HealthKit services started successfully")
            } catch {
                print("Error setting up services: \(error)")
            }
        }
    }
}
