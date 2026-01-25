import SwiftUI
import SwiftData

/// Main dashboard view - bloop. "Parent Dashboard"
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = TodayViewModel()
    @ObservedObject private var routeMonitor = AudioRouteMonitor.shared
    @Query private var userSettings: [UserSettings]

    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // AI Insight Card (Hearing Budget) - Primary focus
                    AIInsightCard(
                        dosePercent: viewModel.todayDose?.dosePercent ?? 0,
                        insight: viewModel.aiInsight,
                        lastUpdated: viewModel.lastUpdated
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.1)

                    // Primary Audio Card (Exposure Zones)
                    PrimaryAudioCard(
                        bands: viewModel.exposureBands,
                        currentLevelDB: viewModel.currentLevelDB
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.2)

                    notificationGateStatusCard
                        .padding(.horizontal)
                        .cardEntrance(delay: 0.25)

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
            // Refresh headphone status on appear
            routeMonitor.refresh()
            // Load data - initial sync is handled by HearingAppApp.setupServices()
            Task {
                await viewModel.loadData()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Restart live streaming (may have been killed by iOS in background)
                HealthKitSyncService.shared.startLiveUpdates()
                // Reload local data when returning to foreground
                Task {
                    await viewModel.loadDataSilently()
                }
            }
        }
    }
}

private extension TodayView {
    var notificationGateStatusCard: some View {
        let settings = userSettings.first
        let lastSampleDate = viewModel.todaySamples.last?.endDate
        let isRecent = lastSampleDate.map { Date().timeIntervalSince($0) <= AgenticRecommendationService.recentSampleWindowSeconds } ?? false
        let isListening = viewModel.aiInsight.isActivelyListening
        let isHeadphones = routeMonitor.currentOutputType.isHeadphoneType
        let instantAlerts = settings?.instantVolumeAlerts ?? true
        let quietHours = isInQuietHours(settings: settings)
        let levelText = viewModel.currentLevelDB.map { "\(Int($0)) dB" } ?? "--"

        return VStack(alignment: .leading, spacing: 8) {
            Text("Notification Gates")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.label)

            Text("Listening: \(yesNo(isListening)) • Recent: \(yesNo(isRecent)) • Headphones: \(yesNo(isHeadphones))")
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)

            Text("Quiet Hours: \(yesNo(quietHours)) • Instant Alerts: \(yesNo(instantAlerts)) • Level: \(levelText)")
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)

            Text("Last Sample: \(lastSampleAgeText(from: lastSampleDate))")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.tertiaryLabel)

            Button {
                Task {
                    let dosePercent = viewModel.todayDose?.dosePercent ?? 0
                    let body = "Manual notification at \(levelText), dose \(Int(dosePercent))%."
                    await NotificationService.shared.sendManualNotification(title: "Test Notification", body: body)
                }
            } label: {
                Text("Send Test Notification")
                    .font(AppTypography.buttonSmall)
                    .foregroundColor(AppColors.primaryFallback)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColors.primaryFallback.opacity(0.12))
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.secondaryBackground)
        )
    }

    func lastSampleAgeText(from date: Date?) -> String {
        guard let date else { return "No samples yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    func isInQuietHours(settings: UserSettings?) -> Bool {
        guard let settings,
              settings.quietHoursEnabled,
              let start = settings.quietHoursStart,
              let end = settings.quietHoursEnd else {
            return false
        }

        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: Date())
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)

        guard let nowMinutes = minutes(from: nowComponents),
              let startMinutes = minutes(from: startComponents),
              let endMinutes = minutes(from: endComponents) else {
            return false
        }

        if startMinutes <= endMinutes {
            return nowMinutes >= startMinutes && nowMinutes <= endMinutes
        }

        return nowMinutes >= startMinutes || nowMinutes <= endMinutes
    }

    func minutes(from components: DateComponents) -> Int? {
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return hour * 60 + minute
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

// MARK: - Headphone Status Indicator

/// Minimal headphone status - just an icon that's green when connected, gray when not
struct HeadphoneStatusDot: View {
    let isConnected: Bool
    
    var body: some View {
        Image(systemName: "headphones")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isConnected ? AppColors.safe : AppColors.tertiaryLabel)
            .animation(.easeInOut(duration: 0.2), value: isConnected)
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environmentObject(AppState())
        .modelContainer(for: [DailyDose.self, ExposureSample.self, ExposureEvent.self])
}
