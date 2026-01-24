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
                // Configure sync service with model context
                HealthKitSyncService.shared.configure(modelContext: sharedModelContainer.mainContext)

                // Configure weekly digest scheduler
                WeeklyDigestScheduler.shared.configure(modelContext: sharedModelContainer.mainContext)

                // Configure personalization service
                PersonalizationService.shared.configure(modelContext: sharedModelContainer.mainContext)

                // Enable background delivery
                HealthKitService.shared.enableBackgroundDelivery()

                // Register notification categories
                NotificationService.shared.registerCategories()

                // Schedule weekly digest notification
                await WeeklyDigestScheduler.shared.scheduleWeeklyDigestNotification()

                // Check if we need to do a full reset (one-time migration to fix duplicates)
                let needsReset = !UserDefaults.standard.bool(forKey: "hasPerformedDataReset_v2")
                
                if HealthKitService.shared.checkAuthorizationStatus() == .authorized {
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
                }
            } catch {
                print("Error setting up services: \(error)")
            }
        }
    }
}
