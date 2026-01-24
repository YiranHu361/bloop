import SwiftUI
import SwiftData

/// Main dashboard view with glassmorphism design
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = TodayViewModel()

    @State private var isMonitoringPaused = false
    @State private var showAlert = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Live Risk Indicator
                    LiveRiskIndicator(
                        dosePercent: viewModel.todayDose?.dosePercent ?? 0,
                        currentLevelDB: viewModel.currentLevelDB,
                        isMonitoring: !isMonitoringPaused
                    )
                    .frame(width: 280, height: 280)
                    .padding(.vertical, 16)
                    .cardEntrance(delay: 0.1)

                    // Session Summary Card
                    SessionSummaryCard(
                        averageDB: viewModel.todayDose?.averageLevelDBASPL,
                        peakDB: viewModel.todayDose?.peakLevelDBASPL,
                        listeningTime: viewModel.todayDose?.totalExposureSeconds ?? 0,
                        dosePercent: viewModel.todayDose?.dosePercent ?? 0
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.2)

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .background(GradientBackground())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            Task { await viewModel.loadData() }
            viewModel.startPeriodicRefresh()
        }
        .onDisappear {
            viewModel.stopPeriodicRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.silentRefresh() }
                viewModel.startPeriodicRefresh()
            } else if newPhase == .background {
                viewModel.stopPeriodicRefresh()
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppState())
        .modelContainer(for: [DailyDose.self, ExposureSample.self])
}
