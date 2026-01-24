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
    @Published var exposureBands: [ExposureBand] = []
    @Published var exposureTimeline: [ExposureTimelinePoint] = []
    @Published var currentLevelDB: Double?
    @Published var exposureSummary: String?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var lastUpdated: Date?
    
    // Safe Listening Score data
    @Published var safeListeningScore: Int = 100
    @Published var currentStreak: Int = 0
    @Published var scoreTrend: SafeListeningScoreCard.ScoreTrend = .stable
    @Published var isInitialLoadComplete: Bool = false

    // AI Insight data
    @Published var aiInsight: AIInsight = .inactive
    @Published var geminiInsightMessage: String?
    @Published var isLoadingGeminiInsight: Bool = false

    private var modelContext: ModelContext?
    private var lastGeminiFetchTime: Date?
    private let geminiRefreshInterval: TimeInterval = 60 // Fetch new AI advice every 1 minute max
    private var cancellables = Set<AnyCancellable>()
    private var doseModel: DoseModel = .niosh
    private var refreshTimer: Timer?
    private var isRefreshInProgress = false
    
    /// Refresh interval in seconds (while dashboard is visible)
    /// Reduced to 2 seconds for more responsive real-time updates
    static let refreshInterval: TimeInterval = 2
    
    var currentStatus: ExposureStatus {
        guard let dose = todayDose else { return .safe }
        return ExposureStatus.from(dosePercent: dose.dosePercent)
    }
    
    func setup(modelContext: ModelContext, doseModel: DoseModel = .niosh) {
        self.modelContext = modelContext
        self.doseModel = doseModel
        subscribeToHealthKitUpdates()
    }
    
    // MARK: - Real-time Refresh
    
    /// Subscribe to HealthKit data update notifications for real-time updates
    private func subscribeToHealthKitUpdates() {
        NotificationCenter.default.publisher(for: .healthKitDataUpdated)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)  // Faster response
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss"
                    print("🎯 [\(formatter.string(from: Date()))] HealthKit data notification received")
                    // Use silent load to avoid flashing loading indicator
                    await self?.loadDataSilently()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Start periodic refresh timer (call when view appears)
    func startPeriodicRefresh() {
        guard isInitialLoadComplete else { return }  // Prevent timer before initial load
        stopPeriodicRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.silentRefresh()
            }
        }
    }
    
    /// Stop periodic refresh timer (call when view disappears)
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Silent refresh that doesn't show loading indicator (for background updates)
    func silentRefresh() async {
        let refreshTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("🔄 [\(formatter.string(from: refreshTime))] Live exposure refresh triggered")

        // Don't block if already refreshing - just skip the sync but still reload local data
        if !isRefreshInProgress {
            isRefreshInProgress = true
            do {
                try await HealthKitSyncService.shared.performIncrementalSync()
            } catch {
                print("Silent sync error: \(error)")
            }
            isRefreshInProgress = false
        }
        // Always reload local data even if sync was skipped
        await loadDataSilently()
    }
    
    /// Load data without showing loading indicator
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
                dose.year == year &&
                dose.month == month &&
                dose.day == day
            }
            
            let doseDescriptor = FetchDescriptor<DailyDose>(predicate: dosePredicate)
            let doses = try context.fetch(doseDescriptor)
            todayDose = doses.first
            
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) else { return }
            let eventPredicate = #Predicate<ExposureEvent> { event in
                event.startDate >= today && event.startDate < endOfDay
            }

            var eventDescriptor = FetchDescriptor<ExposureEvent>(predicate: eventPredicate)
            eventDescriptor.sortBy = [SortDescriptor(\.startDate, order: .reverse)]
            eventDescriptor.fetchLimit = 10

            recentEvents = try context.fetch(eventDescriptor)

            let samplePredicate = #Predicate<ExposureSample> { sample in
                sample.startDate >= today && sample.startDate < endOfDay
            }

            var sampleDescriptor = FetchDescriptor<ExposureSample>(predicate: samplePredicate)
            sampleDescriptor.sortBy = [SortDescriptor(\.startDate, order: .forward)]
            todaySamples = try context.fetch(sampleDescriptor)

            rebuildAnalytics()
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
            // Load today's dose
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
            
            guard let year = todayComponents.year,
                  let month = todayComponents.month,
                  let day = todayComponents.day else { return }

            let dosePredicate = #Predicate<DailyDose> { dose in
                dose.year == year &&
                dose.month == month &&
                dose.day == day
            }
            
            let doseDescriptor = FetchDescriptor<DailyDose>(predicate: dosePredicate)
            let doses = try context.fetch(doseDescriptor)
            todayDose = doses.first
            
            // Load recent events (today only)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) else { return }
            let eventPredicate = #Predicate<ExposureEvent> { event in
                event.startDate >= today && event.startDate < endOfDay
            }

            var eventDescriptor = FetchDescriptor<ExposureEvent>(predicate: eventPredicate)
            eventDescriptor.sortBy = [SortDescriptor(\.startDate, order: .reverse)]
            eventDescriptor.fetchLimit = 10

            recentEvents = try context.fetch(eventDescriptor)

            // Load today's samples for analytics/visualizations
            let samplePredicate = #Predicate<ExposureSample> { sample in
                sample.startDate >= today && sample.startDate < endOfDay
            }

            var sampleDescriptor = FetchDescriptor<ExposureSample>(predicate: samplePredicate)
            sampleDescriptor.sortBy = [SortDescriptor(\.startDate, order: .forward)]
            todaySamples = try context.fetch(sampleDescriptor)

            rebuildAnalytics()
            lastUpdated = Date()
            
            // Calculate Safe Listening Score
            await calculateSafeListeningScore()

            isInitialLoadComplete = true

        } catch {
            self.error = error
        }
    }
    
    func refresh() async {
        guard !isRefreshInProgress else { return }
        isRefreshInProgress = true
        defer { isRefreshInProgress = false }
        
        // Trigger HealthKit sync and reload
        do {
            try await HealthKitSyncService.shared.performIncrementalSync()
        } catch {
            print("Sync error: \(error)")
        }
        await loadData()
    }

    // MARK: - Safe Listening Score Calculation
    
    private func calculateSafeListeningScore() async {
        guard let context = modelContext else { return }
        
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            // Fetch last 7 days
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return }
            
            let weekComponents = calendar.dateComponents([.year, .month, .day], from: weekAgo)
            guard let weekYear = weekComponents.year,
                  let weekMonth = weekComponents.month,
                  let weekDay = weekComponents.day else { return }
            
            let recentPredicate = #Predicate<DailyDose> { dose in
                (dose.year > weekYear ||
                 (dose.year == weekYear && dose.month > weekMonth) ||
                 (dose.year == weekYear && dose.month == weekMonth && dose.day >= weekDay))
            }
            
            let recentDescriptor = FetchDescriptor<DailyDose>(
                predicate: recentPredicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let recentDoses = try context.fetch(recentDescriptor)
            
            // Calculate score
            safeListeningScore = SafeListeningScoreCalculator.calculateScore(from: recentDoses)
            currentStreak = SafeListeningScoreCalculator.calculateStreak(from: recentDoses)
            
            // Fetch older week for trend comparison
            guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) else { return }
            
            let twoWeekComponents = calendar.dateComponents([.year, .month, .day], from: twoWeeksAgo)
            guard let twoWeekYear = twoWeekComponents.year,
                  let twoWeekMonth = twoWeekComponents.month,
                  let twoWeekDay = twoWeekComponents.day else { return }
            
            let olderPredicate = #Predicate<DailyDose> { dose in
                (dose.year > twoWeekYear ||
                 (dose.year == twoWeekYear && dose.month > twoWeekMonth) ||
                 (dose.year == twoWeekYear && dose.month == twoWeekMonth && dose.day >= twoWeekDay)) &&
                (dose.year < weekYear ||
                 (dose.year == weekYear && dose.month < weekMonth) ||
                 (dose.year == weekYear && dose.month == weekMonth && dose.day < weekDay))
            }
            
            let olderDescriptor = FetchDescriptor<DailyDose>(predicate: olderPredicate)
            let olderDoses = try context.fetch(olderDescriptor)
            
            scoreTrend = SafeListeningScoreCalculator.calculateTrend(
                recentDoses: recentDoses,
                olderDoses: olderDoses
            )
            
        } catch {
            print("Error calculating score: \(error)")
        }
    }

    // MARK: - Analytics

    private func rebuildAnalytics() {
        guard !todaySamples.isEmpty else {
            exposureBands = Self.emptyBands()
            exposureTimeline = []
            currentLevelDB = nil
            exposureSummary = nil
            aiInsight = .inactive
            return
        }

        let newLevel = todaySamples.last?.levelDBASPL
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())

        if let level = newLevel {
            let dosePercent = todayDose?.dosePercent ?? 0
            print("📊 [\(timestamp)] Current dB: \(String(format: "%.1f", level)) | Dose: \(String(format: "%.1f", dosePercent))% | Samples today: \(todaySamples.count)")
        }

        currentLevelDB = newLevel
        exposureBands = Self.buildBands(from: todaySamples)
        exposureTimeline = Self.buildTimeline(from: todaySamples)
        exposureSummary = Self.buildSummary(from: todayDose, samples: todaySamples)

        // Calculate AI insight
        calculateAIInsight()
    }

    // MARK: - AI Insight Calculation

    private func calculateAIInsight() {
        let currentDose = todayDose?.dosePercent ?? 0

        // Get samples from the last 30 minutes for burn rate calculation
        let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
        let recentSamples = todaySamples.filter { $0.startDate >= thirtyMinutesAgo }

        // Get typical burn rate from personalization if available
        let typicalBurnRate = calculateTypicalBurnRate()

        let calculator = DoseCalculator(model: doseModel)
        var insight = calculator.generateInsight(
            currentDosePercent: currentDose,
            recentSamples: recentSamples,
            typicalBurnRate: typicalBurnRate
        )

        // If we have a Gemini message, use it instead of the default
        if let geminiMessage = geminiInsightMessage {
            insight = AIInsight(
                type: insight.type,
                message: geminiMessage,
                etaToLimit: insight.etaToLimit,
                estimatedLimitTime: insight.estimatedLimitTime,
                burnRatePerHour: insight.burnRatePerHour,
                isActivelyListening: insight.isActivelyListening
            )
        }

        aiInsight = insight

        // Fetch new Gemini insight if needed (rate limited)
        Task {
            await fetchGeminiInsightIfNeeded()
        }
    }

    // MARK: - Gemini AI Integration

    /// Fetch personalized insight from Gemini API (rate limited)
    private func fetchGeminiInsightIfNeeded() async {
        // Check if API is configured
        guard APIConfig.isGeminiConfigured else { return }

        // Rate limit: don't fetch more often than every 30 seconds
        if let lastFetch = lastGeminiFetchTime,
           Date().timeIntervalSince(lastFetch) < geminiRefreshInterval {
            return
        }

        // Don't fetch if already loading
        guard !isLoadingGeminiInsight else { return }

        // Only fetch if actively listening
        guard aiInsight.isActivelyListening else { return }

        isLoadingGeminiInsight = true
        defer { isLoadingGeminiInsight = false }

        lastGeminiFetchTime = Date()

        do {
            let message = try await GeminiService.shared.generateHearingInsight(
                dosePercent: todayDose?.dosePercent ?? 0,
                burnRatePerHour: aiInsight.burnRatePerHour,
                etaMinutes: aiInsight.etaToLimit.map { $0 / 60 },
                isActivelyListening: aiInsight.isActivelyListening,
                averageDB: todayDose?.averageLevelDBASPL,
                peakDB: todayDose?.peakLevelDBASPL
            )

            // Update the message and rebuild the insight
            geminiInsightMessage = message

            // Rebuild insight with new message
            let calculator = DoseCalculator(model: doseModel)
            let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
            let recentSamples = todaySamples.filter { $0.startDate >= thirtyMinutesAgo }
            let typicalBurnRate = calculateTypicalBurnRate()

            var insight = calculator.generateInsight(
                currentDosePercent: todayDose?.dosePercent ?? 0,
                recentSamples: recentSamples,
                typicalBurnRate: typicalBurnRate
            )

            insight = AIInsight(
                type: insight.type,
                message: message,
                etaToLimit: insight.etaToLimit,
                estimatedLimitTime: insight.estimatedLimitTime,
                burnRatePerHour: insight.burnRatePerHour,
                isActivelyListening: insight.isActivelyListening
            )

            aiInsight = insight

        } catch {
            // Silently fail - we'll use the default message
            print("Gemini insight error: \(error.localizedDescription)")
        }
    }

    /// Calculate typical burn rate from historical data
    private func calculateTypicalBurnRate() -> Double? {
        guard let context = modelContext else { return nil }

        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Get last 7 days of data (excluding today)
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
                return nil
            }

            let weekAgoComponents = calendar.dateComponents([.year, .month, .day], from: weekAgo)
            let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

            guard let weekYear = weekAgoComponents.year,
                  let weekMonth = weekAgoComponents.month,
                  let weekDay = weekAgoComponents.day,
                  let todayYear = todayComponents.year,
                  let todayMonth = todayComponents.month,
                  let todayDay = todayComponents.day else {
                return nil
            }

            // Fetch historical daily doses (excluding today)
            let predicate = #Predicate<DailyDose> { dose in
                (dose.year > weekYear ||
                 (dose.year == weekYear && dose.month > weekMonth) ||
                 (dose.year == weekYear && dose.month == weekMonth && dose.day >= weekDay)) &&
                !(dose.year == todayYear && dose.month == todayMonth && dose.day == todayDay)
            }

            let descriptor = FetchDescriptor<DailyDose>(predicate: predicate)
            let historicalDoses = try context.fetch(descriptor)

            guard !historicalDoses.isEmpty else { return nil }

            // Calculate average dose per hour of listening
            var totalDose: Double = 0
            var totalListeningHours: Double = 0

            for dose in historicalDoses {
                totalDose += dose.dosePercent
                totalListeningHours += dose.totalExposureSeconds / 3600.0
            }

            guard totalListeningHours > 0 else { return nil }

            return totalDose / totalListeningHours
        } catch {
            print("Error calculating typical burn rate: \(error)")
            return nil
        }
    }

    // Build 8 loudness zone bars from time spent at each dB level
    private static func buildBands(from samples: [ExposureSample]) -> [ExposureBand] {
        let zones: [(id: String, label: String, short: String, min: Double, max: Double?, color: Color)] = [
            ("1", "<60", "<60", 0, 60, AppColors.safe),
            ("2", "60-70", "60-70", 60, 70, AppColors.safe.opacity(0.85)),
            ("3", "70-80", "70-80", 70, 80, AppColors.safe.opacity(0.7)),
            ("4", "80-85", "80-85", 80, 85, AppColors.caution.opacity(0.85)),
            ("5", "85-90", "85-90", 85, 90, AppColors.caution),
            ("6", "90-95", "90-95", 90, 95, AppColors.danger.opacity(0.9)),
            ("7", "95-100", "95-100", 95, 100, AppColors.danger),
            ("8", "100+", "100+", 100, nil, AppColors.danger.opacity(0.75)),
        ]

        var secondsByZone: [String: Double] = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, 0) })

        for s in samples {
            let level = s.levelDBASPL
            let duration = max(0, s.duration)
            guard duration > 0 else { continue }

            if level < 60 {
                secondsByZone["1", default: 0] += duration
            } else if level < 70 {
                secondsByZone["2", default: 0] += duration
            } else if level < 80 {
                secondsByZone["3", default: 0] += duration
            } else if level < 85 {
                secondsByZone["4", default: 0] += duration
            } else if level < 90 {
                secondsByZone["5", default: 0] += duration
            } else if level < 95 {
                secondsByZone["6", default: 0] += duration
            } else if level < 100 {
                secondsByZone["7", default: 0] += duration
            } else {
                secondsByZone["8", default: 0] += duration
            }
        }

        return zones.map { z in
            ExposureBand(
                id: z.id,
                label: z.label,
                shortLabel: z.short,
                seconds: secondsByZone[z.id, default: 0],
                color: z.color
            )
        }
    }

    private static func buildTimeline(from samples: [ExposureSample]) -> [ExposureTimelinePoint] {
        guard !samples.isEmpty else { return [] }
        
        // Gap threshold: if consecutive samples are more than 5 minutes apart,
        // start a new segment to avoid drawing a misleading line across the gap
        let gapThresholdSeconds: TimeInterval = 5 * 60
        let maxPoints = 60
        
        // First, downsample if needed
        let sampledData: [ExposureSample]
        if samples.count > maxPoints {
            let stride = max(1, samples.count / maxPoints)
            sampledData = samples.enumerated().compactMap { idx, s in
                idx % stride == 0 ? s : nil
            }
        } else {
            sampledData = samples
        }
        
        // Now assign segments based on time gaps
        var result: [ExposureTimelinePoint] = []
        var currentSegment = 0
        var previousDate: Date?
        
        for sample in sampledData {
            // Check for gap from previous sample
            if let prevDate = previousDate {
                let gap = sample.startDate.timeIntervalSince(prevDate)
                if gap > gapThresholdSeconds {
                    currentSegment += 1
                }
            }
            
            result.append(ExposureTimelinePoint(
                date: sample.startDate,
                levelDB: sample.levelDBASPL,
                segment: currentSegment
            ))
            previousDate = sample.startDate
        }
        
        return result
    }

    private static func buildSummary(from dose: DailyDose?, samples: [ExposureSample]) -> String {
        let peak = dose?.peakLevelDBASPL ?? samples.map(\.levelDBASPL).max() ?? 0
        let avg = dose?.averageLevelDBASPL ?? {
            let total = samples.reduce(0.0) { $0 + ($1.levelDBASPL * $1.duration) }
            let secs = samples.reduce(0.0) { $0 + $1.duration }
            return secs > 0 ? (total / secs) : 0
        }()

        let timeAbove90 = dose?.timeAbove90dB ?? samples.filter { $0.levelDBASPL >= 90 }.reduce(0.0) { $0 + $1.duration }
        let timeAbove85 = dose?.timeAbove85dB ?? samples.filter { $0.levelDBASPL >= 85 }.reduce(0.0) { $0 + $1.duration }

        if timeAbove90 >= 30 * 60 {
            return "High-risk exposure: sustained time above 90 dB."
        }
        if peak >= 95 && avg < 80 {
            return "Spiky exposure: mostly moderate with sharp loud peaks."
        }
        if timeAbove85 >= 60 * 60 || avg >= 85 {
            return "Sustained loud exposure: extended time near/above 85 dB."
        }
        if timeAbove85 > 0 {
            return "Mixed exposure: mostly safe with some risk segments."
        }
        return "Mostly safe exposure: levels stayed in lower zones today."
    }

    private static func emptyBands() -> [ExposureBand] {
        [
            .init(id: "1", label: "<60", shortLabel: "<60", seconds: 0, color: AppColors.safe),
            .init(id: "2", label: "60-70", shortLabel: "60-70", seconds: 0, color: AppColors.safe.opacity(0.85)),
            .init(id: "3", label: "70-80", shortLabel: "70-80", seconds: 0, color: AppColors.safe.opacity(0.7)),
            .init(id: "4", label: "80-85", shortLabel: "80-85", seconds: 0, color: AppColors.caution.opacity(0.85)),
            .init(id: "5", label: "85-90", shortLabel: "85-90", seconds: 0, color: AppColors.caution),
            .init(id: "6", label: "90-95", shortLabel: "90-95", seconds: 0, color: AppColors.danger.opacity(0.9)),
            .init(id: "7", label: "95-100", shortLabel: "95-100", seconds: 0, color: AppColors.danger),
            .init(id: "8", label: "100+", shortLabel: "100+", seconds: 0, color: AppColors.danger.opacity(0.75)),
        ]
    }
}
