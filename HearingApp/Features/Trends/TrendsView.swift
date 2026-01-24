import SwiftUI
import SwiftData
import Charts

/// Enhanced Trends View - "Your Hearing Patterns"
struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TrendsViewModel()
    @State private var selectedPeriod: TrendPeriod = .week
    @State private var selectedDay: DailyDose?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Safe Listening Score
                    SafeListeningScoreCard(
                        score: viewModel.safeListeningScore,
                        streak: viewModel.currentStreak,
                        trend: viewModel.scoreTrend
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.05)
                    
                    // Period Selector
                    PeriodSelector(selectedPeriod: $selectedPeriod)
                        .padding(.horizontal)
                        .cardEntrance(delay: 0.1)
                    
                    // Period Bar Chart (7D or 30D)
                    PeriodBarChart(
                        doses: viewModel.dailyDoses,
                        periodDays: selectedPeriod.days,
                        selectedDay: $selectedDay
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.2)
                    
                    // Highlights Section
                    HighlightsSection(
                        highestDay: viewModel.highestExposureDay,
                        averageDB: viewModel.averageLevel,
                        loudDays: viewModel.loudDays,
                        trend: viewModel.listeningTrend
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.3)
                    
                    // Summary Stats
                    SummaryStatsGrid(
                        averageLevel: viewModel.formattedAverageLevel,
                        peakLevel: viewModel.formattedPeakLevel,
                        totalTime: viewModel.formattedTotalTime,
                        streak: viewModel.currentStreak
                    )
                    .padding(.horizontal)
                    .cardEntrance(delay: 0.4)
                    
                    // Selected Day Details
                    if let day = selectedDay {
                        SelectedDayCard(dose: day) {
                            withAnimation {
                                selectedDay = nil
                            }
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
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
            Task {
                await viewModel.loadData(for: selectedPeriod)
            }
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task {
                await viewModel.loadData(for: newPeriod)
            }
        }
    }
}

// MARK: - Period Selector

struct PeriodSelector: View {
    @Binding var selectedPeriod: TrendPeriod
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TrendPeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                }) {
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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Period Bar Chart (supports 7D and 30D)

struct PeriodBarChart: View {
    let doses: [DailyDose]
    let periodDays: Int
    @Binding var selectedDay: DailyDose?
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Data structure for each bar in the chart
    private struct ChartItem: Identifiable {
        let id: Int  // daysAgo
        let label: String
        let date: Date
        let dose: DailyDose?
        let percent: Double
    }
    
    private var chartData: [ChartItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()

        return (0..<periodDays).reversed().compactMap { daysAgo -> ChartItem? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }
            
            // Label formatting depends on period length
            let label: String
            if periodDays <= 7 {
                // Short period: use day names
                if daysAgo == 0 {
                    label = "Today"
                } else if daysAgo == 1 {
                    label = "Yday"
                } else {
                    label = dateFormatter.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                }
            } else {
                // Long period (30D): use day of month (e.g., "1", "15", "30")
                let dayOfMonth = calendar.component(.day, from: date)
                if daysAgo == 0 {
                    label = "Today"
                } else {
                    label = "\(dayOfMonth)"
                }
            }

            let dose = doses.first { calendar.isDate($0.date, inSameDayAs: date) }
            return ChartItem(
                id: daysAgo,
                label: label,
                date: date,
                dose: dose,
                percent: dose?.dosePercent ?? 0
            )
        }
    }
    
    /// Whether to use a horizontally scrollable chart (for 30D)
    private var isScrollable: Bool {
        periodDays > 14
    }
    
    /// Bar width based on period
    private var barWidth: MarkDimension {
        if periodDays <= 7 {
            return .automatic
        } else if periodDays <= 14 {
            return .fixed(20)
        } else {
            return .fixed(16)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryFallback)
                
                Text("Sound Exposure")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
                
                Spacer()
                
                // Period indicator
                Text("\(periodDays) days")
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            
            // Chart (scrollable for 30D, auto-scrolls to show most recent days)
            if isScrollable {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            chartContent
                                .frame(width: CGFloat(periodDays) * 24 + 60)  // 24pt per bar + padding
                            
                            // Invisible anchor at the end for auto-scrolling
                            Color.clear
                                .frame(width: 1)
                                .id("chartEnd")
                        }
                    }
                    .onAppear {
                        // Auto-scroll to show most recent days first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scrollProxy.scrollTo("chartEnd", anchor: .trailing)
                            }
                        }
                    }
                    .onChange(of: periodDays) { _, newValue in
                        // Re-scroll when switching to 30D
                        if newValue > 14 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollProxy.scrollTo("chartEnd", anchor: .trailing)
                                }
                            }
                        }
                    }
                }
            } else {
                chartContent
            }
            
            // Legend
            HStack(spacing: 16) {
                legendItem(color: AppColors.safe, label: "Safe (<50%)")
                legendItem(color: AppColors.caution, label: "Moderate (50-80%)")
                legendItem(color: AppColors.danger, label: "High (>80%)")
            }
            .font(AppTypography.caption2)
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
    
    private var chartContent: some View {
        Chart {
            ForEach(chartData) { item in
                BarMark(
                    x: .value("Day", item.label),
                    y: .value("Exposure", item.percent),
                    width: barWidth
                )
                .foregroundStyle(barColor(for: item.percent))
                .cornerRadius(periodDays <= 7 ? 6 : 4)
                .annotation(position: .top) {
                    // Only show annotations for 7D or if value is significant
                    if item.percent > 0 && (periodDays <= 7 || item.percent >= 50) {
                        Text("\(Int(item.percent))%")
                            .font(periodDays <= 7 ? AppTypography.caption2 : .system(size: 8))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
            }
            
            // Safe limit line
            RuleMark(y: .value("Limit", 100))
                .foregroundStyle(AppColors.danger.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("Limit")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.danger)
                }
        }
        .frame(height: 200)
        .chartYScale(domain: 0...max(120, chartData.map { $0.percent }.max() ?? 100))
        .chartXAxis {
            AxisMarks { value in
                if periodDays <= 7 {
                    // Show all labels for 7D
                    AxisValueLabel()
                        .font(AppTypography.caption1)
                        .foregroundStyle(AppColors.secondaryLabel)
                } else {
                    // For 30D, show labels every 5 days or for key dates
                    AxisValueLabel()
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.tertiaryLabel)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel()
                    .font(AppTypography.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let label = proxy.value(atX: location.x, as: String.self),
                           let data = chartData.first(where: { $0.label == label }),
                           let dose = data.dose {
                            withAnimation {
                                selectedDay = dose
                            }
                        }
                    }
            }
        }
    }
    
    private func barColor(for percent: Double) -> Color {
        AppColors.statusColor(for: percent)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(AppColors.tertiaryLabel)
        }
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

// MARK: - Highlights Section

struct HighlightsSection: View {
    let highestDay: (date: Date, percent: Double)?
    let averageDB: Double?
    let loudDays: Int
    let trend: String?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.caution)
                
                Text("Insights")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                if let highest = highestDay {
                    insightRow(
                        icon: "arrow.up.circle.fill",
                        iconColor: AppColors.danger,
                        title: "Highest Exposure",
                        value: "\(Int(highest.percent))% on \(formatDate(highest.date))"
                    )
                }
                
                if let avg = averageDB {
                    insightRow(
                        icon: "waveform",
                        iconColor: AppColors.primaryFallback,
                        title: "Average Level",
                        value: "\(Int(avg)) dB this period"
                    )
                }
                
                // Loud days insight
                insightRow(
                    icon: "speaker.wave.3.fill",
                    iconColor: loudDays > 0 ? AppColors.danger : AppColors.safe,
                    title: "Loud Days (≥90 dB)",
                    value: loudDays > 0 ? "\(loudDays) day\(loudDays == 1 ? "" : "s") with loud peaks" : "No loud peaks this period"
                )
                
                if let trend = trend {
                    insightRow(
                        icon: "clock.fill",
                        iconColor: AppColors.accent,
                        title: "Listening Pattern",
                        value: trend
                    )
                }
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
    
    private func insightRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
                
                Text(value)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.label)
            }
            
            Spacer()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
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

// MARK: - Summary Stats Grid

struct SummaryStatsGrid: View {
    let averageLevel: String
    let peakLevel: String
    let totalTime: String
    let streak: Int
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(
                title: "Avg Level",
                value: averageLevel,
                subtitle: "This period",
                icon: "waveform",
                color: AppColors.primaryFallback
            )
            
            StatCardView(
                title: "Peak Level",
                value: peakLevel,
                subtitle: "Loudest moment",
                icon: "speaker.wave.3.fill",
                color: AppColors.caution
            )
            
            StatCardView(
                title: "Listen Time",
                value: totalTime,
                subtitle: "Total duration",
                icon: "clock",
                color: AppColors.primaryFallback
            )
            
            StatCardView(
                title: "Safe Streak",
                value: "\(streak) days",
                subtitle: "Below limit",
                icon: "flame.fill",
                color: AppColors.safe
            )
        }
    }
}

// MARK: - Selected Day Card

struct SelectedDayCard: View {
    let dose: DailyDose
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: dose.date)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(dateString)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
            
            Divider()
            
            HStack(spacing: 24) {
                statItem(label: "Exposure", value: "\(Int(dose.dosePercent))%", color: AppColors.statusColor(for: dose.dosePercent))
                
                if let avg = dose.averageLevelDBASPL {
                    statItem(label: "Avg dB", value: "\(Int(avg))", color: AppColors.primaryFallback)
                }
                
                if let peak = dose.peakLevelDBASPL {
                    statItem(label: "Peak dB", value: "\(Int(peak))", color: peak >= 90 ? AppColors.danger : AppColors.caution)
                }
                
                statItem(label: "Time", value: dose.formattedExposureTime, color: AppColors.secondaryLabel)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.primaryFallback.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: AppColors.cardShadow, radius: 8, x: 0, y: 4)
    }
    
    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.statNumberSmall)
                .foregroundColor(color)
            
            Text(label)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.tertiaryLabel)
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.25)
            } else {
                Color.white
            }
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Trend Period

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

// MARK: - Preview

#Preview {
    TrendsView()
        .modelContainer(for: [DailyDose.self])
}
