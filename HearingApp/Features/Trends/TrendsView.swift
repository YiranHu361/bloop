import SwiftUI
import SwiftData
import Charts

/// Enhanced Trends View
struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TrendsViewModel()
    @State private var selectedPeriod: TrendPeriod = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    PeriodSelector(selectedPeriod: $selectedPeriod)
                        .padding(.horizontal)
                        .cardEntrance(delay: 0.1)

                    // Weekly Bar Chart
                    WeeklyBarChart(doses: viewModel.dailyDoses)
                        .padding(.horizontal)
                        .cardEntrance(delay: 0.2)

                    // Summary Stats
                    SummaryStatsGrid(
                        averageDose: viewModel.averageDose,
                        daysOverLimit: viewModel.daysOverLimit,
                        totalTime: viewModel.formattedTotalTime,
                        streak: viewModel.currentStreak
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.3)

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(GradientBackground())
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            Task { await viewModel.loadData(for: selectedPeriod) }
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task { await viewModel.loadData(for: newPeriod) }
        }
    }
}

struct PeriodSelector: View {
    @Binding var selectedPeriod: TrendPeriod

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TrendPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.displayName)
                        .font(AppTypography.buttonMedium)
                        .foregroundColor(selectedPeriod == period ? .white : AppColors.label)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedPeriod == period ? AppColors.primaryFallback : Color.gray.opacity(0.15))
                        )
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
    }
}

struct WeeklyBarChart: View {
    let doses: [DailyDose]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryFallback)

                Text("Weekly Overview")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)

                Spacer()
            }

            if doses.isEmpty {
                Text("No data for this period")
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(height: 200)
            } else {
                Chart(doses, id: \.date) { dose in
                    BarMark(
                        x: .value("Day", dose.date, unit: .day),
                        y: .value("Dose", dose.dosePercent)
                    )
                    .foregroundStyle(AppColors.statusColor(for: dose.dosePercent))
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...max(120, doses.map { $0.dosePercent }.max() ?? 100))
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
}

struct SummaryStatsGrid: View {
    let averageDose: Double
    let daysOverLimit: Int
    let totalTime: String
    let streak: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(title: "Avg. Dose", value: "\(Int(averageDose))%", icon: "chart.line.uptrend.xyaxis", color: AppColors.statusColor(for: averageDose))
            StatCardView(title: "Days Over", value: "\(daysOverLimit)", subtitle: "Above 100%", icon: "exclamationmark.triangle", color: daysOverLimit > 0 ? AppColors.danger : AppColors.safe)
            StatCardView(title: "Listen Time", value: totalTime, icon: "clock", color: AppColors.primaryFallback)
            StatCardView(title: "Safe Streak", value: "\(streak) days", icon: "flame.fill", color: AppColors.safe)
        }
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(AppTypography.statNumber)
                .foregroundColor(AppColors.label)

            Text(title)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cardBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.15)
            } else {
                Color.white.opacity(0.6)
            }
        }
        .background(.ultraThinMaterial)
    }
}

enum TrendPeriod: String, CaseIterable {
    case week = "7D"
    case month = "30D"

    var displayName: String { rawValue }
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}
