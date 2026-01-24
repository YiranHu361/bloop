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
    
    // MARK: - Computed Properties
    
    var averageDose: Double {
        guard !dailyDoses.isEmpty else { return 0 }
        let total = dailyDoses.reduce(0.0) { $0 + $1.dosePercent }
        return total / Double(dailyDoses.count)
    }
    
    var daysOverLimit: Int {
        dailyDoses.filter { $0.dosePercent >= 100 }.count
    }
    
    var averageLevel: Double? {
        let levelsWithData = dailyDoses.compactMap { $0.averageLevelDBASPL }
        guard !levelsWithData.isEmpty else { return nil }
        return levelsWithData.reduce(0, +) / Double(levelsWithData.count)
    }
    
    var totalExposureSeconds: Double {
        dailyDoses.reduce(0.0) { $0 + $1.totalExposureSeconds }
    }
    
    var formattedTotalTime: String {
        let hours = Int(totalExposureSeconds) / 3600
        let minutes = (Int(totalExposureSeconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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
    
    var highestExposureDay: (date: Date, percent: Double)? {
        guard let highest = dailyDoses.max(by: { $0.dosePercent < $1.dosePercent }) else {
            return nil
        }
        return (highest.date, highest.dosePercent)
    }
    
    var lowestExposureDay: (date: Date, percent: Double)? {
        guard let lowest = dailyDoses.filter({ $0.dosePercent > 0 }).min(by: { $0.dosePercent < $1.dosePercent }) else {
            return nil
        }
        return (lowest.date, lowest.dosePercent)
    }
    
    var listeningTrend: String? {
        guard dailyDoses.count >= 3 else { return nil }
        
        let calendar = Calendar.current
        
        // Check for weekend vs weekday pattern
        let weekdayDoses = dailyDoses.filter { dose in
            let weekday = calendar.component(.weekday, from: dose.date)
            return weekday >= 2 && weekday <= 6
        }
        let weekendDoses = dailyDoses.filter { dose in
            let weekday = calendar.component(.weekday, from: dose.date)
            return weekday == 1 || weekday == 7
        }
        
        let weekdayAvg = weekdayDoses.isEmpty ? 0 : weekdayDoses.reduce(0.0) { $0 + $1.dosePercent } / Double(weekdayDoses.count)
        let weekendAvg = weekendDoses.isEmpty ? 0 : weekendDoses.reduce(0.0) { $0 + $1.dosePercent } / Double(weekendDoses.count)
        
        if weekendAvg > weekdayAvg * 1.3 && !weekendDoses.isEmpty {
            return "You tend to listen more on weekends"
        } else if weekdayAvg > weekendAvg * 1.3 && !weekdayDoses.isEmpty {
            return "You tend to listen more on weekdays"
        }
        
        // Check for time-of-day pattern (if we had more granular data)
        // For now, provide general feedback
        if averageDose > 80 {
            return "Your exposure is consistently high"
        } else if averageDose < 40 {
            return "Great job keeping exposure low!"
        }
        
        return "Your listening patterns are fairly consistent"
    }
    
    // MARK: - Setup and Data Loading
    
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
            guard let startDate = calendar.date(byAdding: .day, value: -period.days, to: endDate) else {
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
            
            var descriptor = FetchDescriptor<DailyDose>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
            
            dailyDoses = try context.fetch(descriptor)
        } catch {
            self.error = error
        }
    }
}
