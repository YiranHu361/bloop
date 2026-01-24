import SwiftUI
import SwiftData

@main
struct HearingAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ExposureSample.self,
            DailyDose.self,
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
            ContentView()
                .onAppear {
                    setupHealthKit()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func setupHealthKit() {
        Task {
            if HealthKitService.shared.isAuthorized {
                try? await HealthKitService.shared.fetchAndStoreSamples(
                    context: sharedModelContainer.mainContext,
                    days: 7
                )
            }
        }
    }
}
