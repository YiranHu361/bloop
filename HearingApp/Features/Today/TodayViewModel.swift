import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel for Today (Dashboard) view
@MainActor
final class TodayViewModel: ObservableObject {
    @Published var todayDose: DailyDose?
    @Published var recentEvents: [ExposureEvent] = []
    @Published var todaySamples: [ExposureSample] = []
    @Published var currentLevelDB: Double?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var lastUpdated: Date?

    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var isRefreshInProgress = false

    static let refreshInterval: TimeInterval = 5

    func setup(modelContext: ModelContext, doseModel: DoseModel = .niosh) {
        self.modelContext = modelContext
        subscribeToHealthKitUpdates()
    }

    private func subscribeToHealthKitUpdates() {
        NotificationCenter.default.publisher(for: .healthKitDataUpdated)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }

    func startPeriodicRefresh() {
        stopPeriodicRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.silentRefresh()
            }
        }
    }

    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func silentRefresh() async {
        guard !isRefreshInProgress else { return }
        isRefreshInProgress = true
        defer { isRefreshInProgress = false }

        do {
            try await HealthKitSyncService.shared.performFullSync(days: 1)
        } catch {
            print("Silent sync error: \(error)")
        }
        await loadDataSilently()
    }

    private func loadDataSilently() async {
        guard let context = modelContext else { return }

        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

            guard let year = todayComponents.year,
                  let month = todayComponents.month,
                  let day = todayComponents.day else { return }

            let dosePredicate = #Predicate<DailyDose> { dose in
                dose.year == year && dose.month == month && dose.day == day
            }

            let doseDescriptor = FetchDescriptor<DailyDose>(predicate: dosePredicate)
            let doses = try context.fetch(doseDescriptor)
            todayDose = doses.first

            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) else { return }
            let samplePredicate = #Predicate<ExposureSample> { sample in
                sample.startDate >= today && sample.startDate < endOfDay
            }

            var sampleDescriptor = FetchDescriptor<ExposureSample>(predicate: samplePredicate)
            sampleDescriptor.sortBy = [SortDescriptor(\.startDate, order: .forward)]
            todaySamples = try context.fetch(sampleDescriptor)

            currentLevelDB = todaySamples.last?.levelDBASPL
            lastUpdated = Date()
        } catch {
            print("Silent load error: \(error)")
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func loadData() async {
        guard let context = modelContext else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

            guard let year = todayComponents.year,
                  let month = todayComponents.month,
                  let day = todayComponents.day else { return }

            let dosePredicate = #Predicate<DailyDose> { dose in
                dose.year == year && dose.month == month && dose.day == day
            }

            let doseDescriptor = FetchDescriptor<DailyDose>(predicate: dosePredicate)
            let doses = try context.fetch(doseDescriptor)
            todayDose = doses.first

            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }
            let eventPredicate = #Predicate<ExposureEvent> { event in
                event.startDate >= yesterday
            }

            var eventDescriptor = FetchDescriptor<ExposureEvent>(predicate: eventPredicate)
            eventDescriptor.sortBy = [SortDescriptor(\.startDate, order: .reverse)]
            eventDescriptor.fetchLimit = 10

            recentEvents = try context.fetch(eventDescriptor)

            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) else { return }
            let samplePredicate = #Predicate<ExposureSample> { sample in
                sample.startDate >= today && sample.startDate < endOfDay
            }

            var sampleDescriptor = FetchDescriptor<ExposureSample>(predicate: samplePredicate)
            sampleDescriptor.sortBy = [SortDescriptor(\.startDate, order: .forward)]
            todaySamples = try context.fetch(sampleDescriptor)

            currentLevelDB = todaySamples.last?.levelDBASPL
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }

    func refresh() async {
        guard !isRefreshInProgress else { return }
        isRefreshInProgress = true
        defer { isRefreshInProgress = false }

        do {
            try await HealthKitSyncService.shared.performFullSync(days: 1)
        } catch {
            print("Sync error: \(error)")
        }
        await loadData()
    }
}
