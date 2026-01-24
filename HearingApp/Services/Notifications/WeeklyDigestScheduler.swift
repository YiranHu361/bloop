import Foundation
import SwiftData
import UserNotifications

/// Generates and schedules weekly digest notifications
@MainActor
final class WeeklyDigestScheduler: ObservableObject {
    static let shared = WeeklyDigestScheduler()

    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Digest Generation

    /// Generate weekly digest from DailyDose data
    func generateWeeklyDigest(for weekStartDate: Date? = nil) async throws -> WeeklyDigest? {
        guard let context = modelContext else { return nil }

        let calendar = Calendar.current

        // Determine the week to generate for
        let targetWeekStart: Date
        if let specified = weekStartDate {
            targetWeekStart = calendar.startOfDay(for: specified)
        } else {
            // Default to last completed week
            let today = calendar.startOfDay(for: Date())
            guard let lastMonday = calendar.date(byAdding: .day, value: -7, to: previousMonday(from: today)) else {
                return nil
            }
            targetWeekStart = lastMonday
        }

        guard let weekEndDate = calendar.date(byAdding: .day, value: 6, to: targetWeekStart) else {
            return nil
        }

        // Fetch daily doses for this week
        let weekComponents = calendar.dateComponents([.year, .month, .day], from: targetWeekStart)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: weekEndDate)

        guard let weekStartYear = weekComponents.year,
              let weekStartMonth = weekComponents.month,
              let weekStartDay = weekComponents.day,
              let weekEndYear = endComponents.year,
              let weekEndMonth = endComponents.month,
              let weekEndDay = endComponents.day else {
            return nil
        }

        // Fetch all doses in the range
        let predicate = #Predicate<DailyDose> { dose in
            (dose.year > weekStartYear ||
             (dose.year == weekStartYear && dose.month > weekStartMonth) ||
             (dose.year == weekStartYear && dose.month == weekStartMonth && dose.day >= weekStartDay)) &&
            (dose.year < weekEndYear ||
             (dose.year == weekEndYear && dose.month < weekEndMonth) ||
             (dose.year == weekEndYear && dose.month == weekEndMonth && dose.day <= weekEndDay))
        }

        let descriptor = FetchDescriptor<DailyDose>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        let doses = try context.fetch(descriptor)

        guard !doses.isEmpty else { return nil }

        // Calculate metrics
        let averageDose = doses.reduce(0.0) { $0 + $1.dosePercent } / Double(doses.count)
        let totalTime = doses.reduce(0.0) { $0 + $1.totalExposureSeconds }
        let daysOverLimit = doses.filter { $0.dosePercent >= 100 }.count

        // Find loudest and quietest days
        let sortedByDose = doses.sorted { $0.dosePercent > $1.dosePercent }
        let loudestDay = sortedByDose.first
        let quietestDay = sortedByDose.last

        // Calculate average level
        let levelsWithData = doses.compactMap { $0.averageLevelDBASPL }
        let averageLevel = levelsWithData.isEmpty ? nil : levelsWithData.reduce(0.0, +) / Double(levelsWithData.count)

        // Get previous week's data for comparison
        let previousWeekAverage = try await getPreviousWeekAverage(before: targetWeekStart)

        // Calculate streak
        let (currentStreak, bestStreak) = try calculateStreaks()

        // Create digest
        let digest = WeeklyDigest(
            weekStartDate: targetWeekStart,
            weekEndDate: weekEndDate,
            averageDosePercent: averageDose,
            previousWeekAveragePercent: previousWeekAverage,
            totalListeningTimeSeconds: totalTime,
            daysWithData: doses.count,
            daysOverLimit: daysOverLimit,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            loudestDayDate: loudestDay?.date,
            loudestDayDosePercent: loudestDay?.dosePercent,
            quietestDayDate: quietestDay?.date,
            quietestDayDosePercent: quietestDay?.dosePercent,
            averageLevelDBASPL: averageLevel
        )

        // Check if digest already exists for this week
        let digestYear = digest.year
        let digestWeekOfYear = digest.weekOfYear
        let existingPredicate = #Predicate<WeeklyDigest> { existing in
            existing.year == digestYear && existing.weekOfYear == digestWeekOfYear
        }
        let existingDescriptor = FetchDescriptor<WeeklyDigest>(predicate: existingPredicate)
        let existingDigests = try context.fetch(existingDescriptor)

        if let existing = existingDigests.first {
            // Update existing
            existing.averageDosePercent = digest.averageDosePercent
            existing.previousWeekAveragePercent = digest.previousWeekAveragePercent
            existing.totalListeningTimeSeconds = digest.totalListeningTimeSeconds
            existing.daysWithData = digest.daysWithData
            existing.daysOverLimit = digest.daysOverLimit
            existing.currentStreak = digest.currentStreak
            existing.bestStreak = digest.bestStreak
            existing.loudestDayDate = digest.loudestDayDate
            existing.loudestDayDosePercent = digest.loudestDayDosePercent
            existing.quietestDayDate = digest.quietestDayDate
            existing.quietestDayDosePercent = digest.quietestDayDosePercent
            existing.averageLevelDBASPL = digest.averageLevelDBASPL
            existing.generatedAt = Date()
        } else {
            // Insert new
            context.insert(digest)
        }

        try context.save()
        return digest
    }

    // MARK: - Scheduling

    /// Schedule Monday morning notification for weekly digest
    func scheduleWeeklyDigestNotification() async {
        guard await NotificationService.shared.isAuthorized else { return }

        let center = UNUserNotificationCenter.current()

        // Remove existing weekly digest notifications
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-digest"])

        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Hearing Report"
        content.body = "See how your listening habits measured up this week. Tap to view your digest."
        content.sound = nil
        content.categoryIdentifier = NotificationCategory.weeklyDigest.rawValue

        // Schedule for Monday at 9 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "weekly-digest",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule weekly digest notification: \(error)")
        }
    }

    func cancelWeeklyDigestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-digest"])
    }

    // MARK: - Helper Methods

    private func previousMonday(from date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let daysToSubtract = (weekday == 1) ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date
    }

    private func getPreviousWeekAverage(before weekStart: Date) async throws -> Double? {
        guard let context = modelContext else { return nil }

        let calendar = Calendar.current
        guard let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart),
              let prevWeekEnd = calendar.date(byAdding: .day, value: 6, to: prevWeekStart) else {
            return nil
        }

        let startComponents = calendar.dateComponents([.year, .month, .day], from: prevWeekStart)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: prevWeekEnd)

        guard let startYear = startComponents.year,
              let startMonth = startComponents.month,
              let startDay = startComponents.day,
              let endYear = endComponents.year,
              let endMonth = endComponents.month,
              let endDay = endComponents.day else {
            return nil
        }

        let predicate = #Predicate<DailyDose> { dose in
            (dose.year > startYear ||
             (dose.year == startYear && dose.month > startMonth) ||
             (dose.year == startYear && dose.month == startMonth && dose.day >= startDay)) &&
            (dose.year < endYear ||
             (dose.year == endYear && dose.month < endMonth) ||
             (dose.year == endYear && dose.month == endMonth && dose.day <= endDay))
        }

        let descriptor = FetchDescriptor<DailyDose>(predicate: predicate)
        let doses = try context.fetch(descriptor)

        guard !doses.isEmpty else { return nil }
        return doses.reduce(0.0) { $0 + $1.dosePercent } / Double(doses.count)
    }

    private func calculateStreaks() throws -> (current: Int, best: Int) {
        guard let context = modelContext else { return (0, 0) }

        let descriptor = FetchDescriptor<DailyDose>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let doses = try context.fetch(descriptor)

        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0

        for dose in doses {
            if dose.dosePercent < 100 {
                tempStreak += 1
                bestStreak = max(bestStreak, tempStreak)
                if currentStreak == tempStreak - 1 {
                    currentStreak = tempStreak
                }
            } else {
                if currentStreak == tempStreak {
                    // First break after current streak
                }
                tempStreak = 0
            }
        }

        return (currentStreak, bestStreak)
    }

    /// Get the most recent weekly digest
    func getMostRecentDigest() throws -> WeeklyDigest? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<WeeklyDigest>(
            sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)]
        )

        let digests = try context.fetch(descriptor)
        return digests.first
    }
}
