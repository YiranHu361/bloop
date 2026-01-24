import SwiftUI
import SwiftData

@main
struct HearingAppApp: App {
    @StateObject private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ExposureSample.self,
            ExposureEvent.self,
            DailyDose.self,
            UserSettings.self,
            SyncState.self,
            WeeklyDigest.self,
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
                HealthKitSyncService.shared.configure(modelContext: sharedModelContainer.mainContext)
                HealthKitService.shared.enableBackgroundDelivery()
                NotificationService.shared.registerCategories()

                if HealthKitService.shared.checkAuthorizationStatus() == .authorized {
                    try await HealthKitSyncService.shared.performFullSync(days: 30)
                    HealthKitSyncService.shared.startLiveUpdates()
                }
            } catch {
                print("Error setting up services: \(error)")
            }
        }
    }
}
