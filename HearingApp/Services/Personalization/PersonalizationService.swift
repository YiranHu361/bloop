import Foundation
import SwiftData
import SwiftUI

/// Service for analyzing user patterns and generating personalized recommendations
@MainActor
final class PersonalizationService: ObservableObject {
    static let shared = PersonalizationService()

    private var modelContext: ModelContext?

    @Published var preferences: PersonalizationPreferences?
    @Published var isAnalyzing = false

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await loadPreferences()
        }
    }

    // MARK: - Preferences Management

    func loadPreferences() async {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<PersonalizationPreferences>()
            let existingPrefs = try context.fetch(descriptor)

            if let prefs = existingPrefs.first {
                self.preferences = prefs
            } else {
                // Create default preferences
                let newPrefs = PersonalizationPreferences()
                context.insert(newPrefs)
                try context.save()
                self.preferences = newPrefs
            }
        } catch {
            print("Error loading personalization preferences: \(error)")
        }
    }

    func setPersonalizationEnabled(_ enabled: Bool) async {
        guard let prefs = preferences else { return }

        prefs.isEnabled = enabled

        if enabled && !prefs.hasEnoughData {
            // Run analysis if enabling for the first time
            await analyzePatterns()
        }

        try? modelContext?.save()
    }

    // MARK: - Pattern Analysis

    /// Analyze 30-day patterns to generate personalized insights
    func analyzePatterns() async {
        guard let context = modelContext else { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            // Fetch last 30 days of data
            let calendar = Calendar.current
            let endDate = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else {
                return
            }

            let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)

            guard let startYear = startComponents.year,
                  let startMonth = startComponents.month,
                  let startDay = startComponents.day,
                  let endYear = endComponents.year,
                  let endMonth = endComponents.month,
                  let endDay = endComponents.day else {
                return
            }

            let predicate = #Predicate<DailyDose> { dose in
                (dose.year > startYear ||
                 (dose.year == startYear && dose.month > startMonth) ||
                 (dose.year == startYear && dose.month == startMonth && dose.day >= startDay)) &&
                (dose.year < endYear ||
                 (dose.year == endYear && dose.month < endMonth) ||
                 (dose.year == endYear && dose.month == endMonth && dose.day <= endDay))
            }

            let descriptor = FetchDescriptor<DailyDose>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date)]
            )

            let doses = try context.fetch(descriptor)

            guard doses.count >= 7 else {
                // Not enough data
                return
            }

            // Calculate averages
            let totalDose = doses.reduce(0.0) { $0 + $1.dosePercent }
            let averageDose = totalDose / Double(doses.count)

            // Separate weekday vs weekend
            let weekdayDoses = doses.filter { dose in
                let weekday = calendar.component(.weekday, from: dose.date)
                return weekday >= 2 && weekday <= 6 // Mon-Fri
            }
            let weekendDoses = doses.filter { dose in
                let weekday = calendar.component(.weekday, from: dose.date)
                return weekday == 1 || weekday == 7 // Sun or Sat
            }

            let weekdayAvg = weekdayDoses.isEmpty ? nil : weekdayDoses.reduce(0.0) { $0 + $1.dosePercent } / Double(weekdayDoses.count)
            let weekendAvg = weekendDoses.isEmpty ? nil : weekendDoses.reduce(0.0) { $0 + $1.dosePercent } / Double(weekendDoses.count)

            // Find peak listening hours (would need more granular data)
            // For now, we'll skip this as we only have daily data

            // Determine pattern type
            let patternType = determinePatternType(
                averageDose: averageDose,
                weekdayAvg: weekdayAvg,
                weekendAvg: weekendAvg,
                doses: doses
            )

            // Calculate recommended early warning
            let recommendedWarning = calculateRecommendedEarlyWarning(
                averageDose: averageDose,
                patternType: patternType
            )

            // Update preferences
            if let prefs = preferences {
                prefs.typicalAverageDose = averageDose
                prefs.weekdayAverageDose = weekdayAvg
                prefs.weekendAverageDose = weekendAvg
                prefs.daysAnalyzed = doses.count
                prefs.lastAnalysisDate = Date()
                prefs.listeningPatternType = patternType.rawValue
                prefs.recommendedEarlyWarning = recommendedWarning

                try context.save()
            }

        } catch {
            print("Error analyzing patterns: \(error)")
        }
    }

    private func determinePatternType(
        averageDose: Double,
        weekdayAvg: Double?,
        weekendAvg: Double?,
        doses: [DailyDose]
    ) -> ListeningPatternType {
        // Check for weekend warrior or workday listener
        if let weekday = weekdayAvg, let weekend = weekendAvg {
            let difference = weekend - weekday
            if difference > 20 {
                return .weekendWarrior
            } else if difference < -20 {
                return .workdayListener
            }
        }

        // Check consistency
        let variance = calculateVariance(doses.map { $0.dosePercent })
        if variance > 600 { // High variance
            return .inconsistent
        }

        // Check overall level
        if averageDose < 40 {
            return .conservative
        } else if averageDose < 70 {
            return .moderate
        } else {
            return .heavy
        }
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }

    private func calculateRecommendedEarlyWarning(
        averageDose: Double,
        patternType: ListeningPatternType
    ) -> Int {
        switch patternType {
        case .conservative:
            return 50 // Standard threshold is fine
        case .moderate:
            return 40 // Slightly earlier warning
        case .heavy:
            return 35 // Earlier warning to help pace
        case .inconsistent:
            return 40
        case .weekendWarrior:
            return 40
        case .workdayListener:
            return 45
        }
    }

    // MARK: - Personalized Messages

    /// Get a personalized notification message based on user patterns
    func getPersonalizedMessage(for threshold: Int, dosePercent: Double) -> String? {
        guard let prefs = preferences, prefs.isEnabled else {
            return nil // Use default messages
        }

        guard let patternTypeRaw = prefs.listeningPatternType,
              let patternType = ListeningPatternType(rawValue: patternTypeRaw) else {
            return nil
        }

        switch threshold {
        case 50:
            switch patternType {
            case .conservative:
                return "You're at 50% - that's more than your usual average. Take it easy!"
            case .heavy:
                return "Halfway there. Based on your patterns, consider slowing down now."
            default:
                return nil // Use default
            }

        case 80:
            switch patternType {
            case .conservative:
                return "80% reached - this is above your typical usage. Your ears could use a break."
            case .weekendWarrior:
                if Calendar.current.isDateInWeekend(Date()) {
                    return "80% on a weekend - you tend to listen more on weekends. Be mindful!"
                }
            default:
                return nil
            }

        case 100:
            if prefs.typicalAverageDose ?? 100 < 80 {
                return "You've hit 100% - that's higher than your usual pattern. Give your ears a rest."
            }

        default:
            break
        }

        return nil
    }

    // MARK: - Insights

    func getInsights() -> [PersonalizationInsight] {
        guard let prefs = preferences, prefs.hasEnoughData else {
            return [
                PersonalizationInsight(
                    title: "Not Enough Data",
                    description: "Use the app for at least 7 days to get personalized insights.",
                    icon: "clock",
                    color: .secondary
                )
            ]
        }

        var insights: [PersonalizationInsight] = []

        // Pattern insight
        if let patternRaw = prefs.listeningPatternType,
           let pattern = ListeningPatternType(rawValue: patternRaw) {
            insights.append(PersonalizationInsight(
                title: pattern.rawValue,
                description: pattern.description,
                icon: iconForPattern(pattern),
                color: colorForPattern(pattern)
            ))
        }

        // Average dose insight
        if let avg = prefs.typicalAverageDose {
            let status = ExposureStatus.from(dosePercent: avg)
            insights.append(PersonalizationInsight(
                title: "Average Daily Dose",
                description: "Your typical daily dose is \(Int(avg))%",
                icon: "chart.line.uptrend.xyaxis",
                color: status.color
            ))
        }

        // Weekday vs Weekend
        if let diff = prefs.weekdayVsWeekendDifference, abs(diff) > 10 {
            let moreOn = diff > 0 ? "weekends" : "weekdays"
            insights.append(PersonalizationInsight(
                title: "Weekly Pattern",
                description: "You listen \(Int(abs(diff)))% more on \(moreOn)",
                icon: "calendar.badge.clock",
                color: .blue
            ))
        }

        // Recommendation
        if let recommended = prefs.recommendedEarlyWarning, recommended < 50 {
            insights.append(PersonalizationInsight(
                title: "Recommendation",
                description: "Consider enabling a \(recommended)% early warning",
                icon: "lightbulb",
                color: .yellow
            ))
        }

        return insights
    }

    private func iconForPattern(_ pattern: ListeningPatternType) -> String {
        switch pattern {
        case .conservative: return "leaf"
        case .moderate: return "equal.circle"
        case .heavy: return "speaker.wave.3"
        case .inconsistent: return "waveform"
        case .weekendWarrior: return "calendar.badge.exclamationmark"
        case .workdayListener: return "briefcase"
        }
    }

    private func colorForPattern(_ pattern: ListeningPatternType) -> Color {
        switch pattern {
        case .conservative: return .green
        case .moderate: return .blue
        case .heavy: return .orange
        case .inconsistent: return .purple
        case .weekendWarrior: return .orange
        case .workdayListener: return .blue
        }
    }
}

// MARK: - Supporting Types

struct PersonalizationInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
}
