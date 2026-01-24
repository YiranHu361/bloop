import SwiftUI
import SwiftData

/// Main dashboard view - bloop. "Parent Dashboard"
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = TodayViewModel()
    @ObservedObject private var routeMonitor = AudioRouteMonitor.shared

    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Primary Audio Card (Exposure Zones)
                    PrimaryAudioCard(
                        bands: viewModel.exposureBands,
                        currentLevelDB: viewModel.currentLevelDB
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.1)

                    // AI Insight Card (Hearing Budget)
                    AIInsightCard(
                        dosePercent: viewModel.todayDose?.dosePercent ?? 0,
                        insight: viewModel.aiInsight,
                        lastUpdated: viewModel.lastUpdated
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.2)

                    // Session Summary Card
                    SessionSummaryCard(
                        averageDB: viewModel.todayDose?.averageLevelDBASPL,
                        peakDB: viewModel.todayDose?.peakLevelDBASPL,
                        listeningTime: viewModel.todayDose?.totalExposureSeconds ?? 0
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.25)

                    // Exposure Details (Timeline / Log) - Last 24 hours
                    ExposureProfileView(
                        timeline: viewModel.exposureTimeline,
                        trendline: viewModel.exposureTrendline,
                        currentLevelDB: viewModel.currentLevelDB,
                        descriptorText: viewModel.exposureSummary,
                        lastUpdated: viewModel.lastUpdated
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.35)

                    // Recent Events
                    if !viewModel.recentEvents.isEmpty {
                        RecentEventsSection(events: viewModel.recentEvents)
                            .padding(.horizontal)
                            .cardEntrance(delay: 0.45)
                    }

                    // Bottom spacing
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
                    HStack(spacing: 12) {
                        // Headphone status indicator
                        HeadphoneStatusDot(isConnected: routeMonitor.isHeadphonesConnected)
                        
                        if viewModel.isLoading || isRefreshing {
                            ProgressView()
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            // Start live streaming immediately
            HealthKitSyncService.shared.startLiveUpdates()
            Task {
                // Force a sync to get latest data
                try? await HealthKitSyncService.shared.performIncrementalSync()
                await viewModel.loadData()
                viewModel.startPeriodicRefresh()
            }
        }
        .onDisappear {
            viewModel.stopPeriodicRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Restart live HealthKit streaming (may have been killed by iOS)
                HealthKitSyncService.shared.startLiveUpdates()
                // Force sync and refresh when returning to foreground
                Task {
                    try? await HealthKitSyncService.shared.performIncrementalSync()
                    await viewModel.silentRefresh()
                }
                viewModel.startPeriodicRefresh()
            } else if newPhase == .background {
                viewModel.stopPeriodicRefresh()
            }
        }
    }
}

// MARK: - Recent Events Section

struct RecentEventsSection: View {
    let events: [ExposureEvent]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.caution)

                Text("Recent Loud Exposures")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)

                Spacer()

                Text("\(events.count)")
                    .font(AppTypography.caption1Bold)
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                    )
            }

            ForEach(events.prefix(3), id: \.healthKitUUID) { event in
                RecentEventRow(event: event)
            }

            if events.count > 3 {
                Button(action: {}) {
                    Text("View all \(events.count) events")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.primaryFallback)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
        .shadow(color: AppColors.cardShadow, radius: 8, x: 0, y: 4)
    }

    private var cardBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.2)
            } else {
                Color.white.opacity(0.9)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.glassBorder.opacity(colorScheme == .dark ? 0.2 : 0.4),
                AppColors.glassBorder.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct RecentEventRow: View {
    let event: ExposureEvent

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: event.startDate, relativeTo: Date())
    }

    private var levelColor: Color {
        guard let level = event.eventLevelDBASPL else { return AppColors.secondaryLabel }
        switch level {
        case ..<85: return AppColors.safe
        case 85..<95: return AppColors.caution
        default: return AppColors.danger
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Level indicator
            ZStack {
                Circle()
                    .fill(levelColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                if let level = event.eventLevelDBASPL {
                    Text("\(Int(level))")
                        .font(AppTypography.caption1Bold)
                        .foregroundColor(levelColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let level = event.eventLevelDBASPL {
                        Text("\(Int(level)) dB exposure")
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.label)
                    }

                    Spacer()

                    Text(timeAgo)
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.tertiaryLabel)
                }

                if let duration = event.eventDurationSeconds {
                    Text("Duration: \(formatDuration(duration))")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }
}

// MARK: - Headphone Status Dot

/// Compact headphone status indicator - green when connected, orange when not
struct HeadphoneStatusDot: View {
    let isConnected: Bool
    
    private var statusColor: Color {
        isConnected ? AppColors.safe : AppColors.caution
    }
    
    private var statusIcon: String {
        isConnected ? "headphones" : "speaker.wave.2"
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
        .animation(.easeInOut(duration: 0.2), value: isConnected)
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environmentObject(AppState())
        .modelContainer(for: [DailyDose.self, ExposureSample.self, ExposureEvent.self])
}
