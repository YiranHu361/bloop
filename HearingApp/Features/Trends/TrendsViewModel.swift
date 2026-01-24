import Foundation
import SwiftUI
import SwiftData

/// ViewModel for Trends view
@MainActor
final class TrendsViewModel: ObservableObject {
    @Published var dailyDoses: [DailyDose] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private var modelContext: ModelContext?

    var averageDose: Double {
        guard !dailyDoses.isEmpty else { return 0 }
        let total = dailyDoses.reduce(0.0) { $0 + $1.dosePercent }
        return total / Double(dailyDoses.count)
    }

    var daysOverLimit: Int {
        dailyDoses.filter { $0.dosePercent >= 100 }.count
    }

    var totalExposureSeconds: Double {
        dailyDoses.reduce(0.0) { $0 + $1.totalExposureSeconds }
    }

    var formattedTotalTime: String {
        let hours = Int(totalExposureSeconds) / 3600
        let minutes = (Int(totalExposureSeconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var currentStreak: Int {
        let sortedDoses = dailyDoses.sorted { $0.date > $1.date }
        var streak = 0

        for dose in sortedDoses {
            if dose.dosePercent < 100 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadData(for period: TrendPeriod) async {
        guard let context = modelContext else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let endDate = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -period.days, to: endDate) else { return }

            let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)

            guard let startYear = startComponents.year,
                  let startMonth = startComponents.month,
                  let startDay = startComponents.day,
                  let endYear = endComponents.year,
                  let endMonth = endComponents.month,
                  let endDay = endComponents.day else { return }

            let predicate = #Predicate<DailyDose> { dose in
                (dose.year > startYear ||
                 (dose.year == startYear && dose.month > startMonth) ||
                 (dose.year == startYear && dose.month == startMonth && dose.day >= startDay)) &&
                (dose.year < endYear ||
                 (dose.year == endYear && dose.month < endMonth) ||
                 (dose.year == endYear && dose.month == endMonth && dose.day <= endDay))
            }

            var descriptor = FetchDescriptor<DailyDose>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]

            dailyDoses = try context.fetch(descriptor)
        } catch {
            self.error = error
        }
    }
}
