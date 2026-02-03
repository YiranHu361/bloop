import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct DoseEntry: TimelineEntry {
    let date: Date
    let dosePercent: Double
    let remainingTime: TimeInterval
    let listeningTime: TimeInterval
    let status: WidgetExposureStatus
    let isStale: Bool
    let lastDataUpdate: Date?

    static let placeholder = DoseEntry(
        date: .now,
        dosePercent: 0,
        remainingTime: 8 * 3600,
        listeningTime: 0,
        status: .safe,
        isStale: false,
        lastDataUpdate: nil
    )

    static let noData = DoseEntry(
        date: .now,
        dosePercent: 0,
        remainingTime: 8 * 3600,
        listeningTime: 0,
        status: .safe,
        isStale: true,
        lastDataUpdate: nil
    )
}

// MARK: - Exposure Status (Widget-specific to avoid main app dependency issues)

enum WidgetExposureStatus: String {
    case safe
    case moderate
    case high
    case dangerous

    var color: Color {
        switch self {
        case .safe: return Color(hex: "34C759")
        case .moderate: return Color(hex: "FF9500")
        case .high: return Color(hex: "FF9500")
        case .dangerous: return Color(hex: "FF3B30")
        }
    }

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .dangerous: return "Over Limit"
        }
    }

    static func from(dosePercent: Double) -> WidgetExposureStatus {
        switch dosePercent {
        case ..<50: return .safe
        case 50..<80: return .moderate
        case 80..<100: return .high
        default: return .dangerous
        }
    }
}

// Color hex extension for widget
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Shared Constants
// Note: Widget extension cannot import main app's AppConfig, so we define shared constants here
// ⚠️ SYNC WARNING: This value MUST match AppConfig.appGroupIdentifier in HearingApp/App/AppConfig.swift
// If you change one, you MUST change the other, or widget/app communication will break!
private enum WidgetConstants {
    static let appGroupIdentifier = "group.com.bloopapp.shared"  // KEEP IN SYNC with AppConfig.appGroupIdentifier
}

// MARK: - Timeline Provider

struct DoseTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> DoseEntry {
        DoseEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) {
        // Use same fallback chain as getTimeline for consistency
        let entry = fetchTodayDose() ?? fetchLastKnownDose() ?? DoseEntry.noData
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        let baseEntry = fetchTodayDose() ?? fetchLastKnownDose() ?? DoseEntry.noData

        // FIXED: Don't project fake dose increases - show actual data only
        // The previous implementation added 1.5% per minute which caused the widget
        // to show inflated values that would "reset" when real data arrived

        // Create a single entry with actual data
        // Widget will refresh based on WidgetCenter.reloadTimelines() called by main app
        let now = Date()

        let entry = DoseEntry(
            date: now,
            dosePercent: baseEntry.dosePercent,
            remainingTime: baseEntry.remainingTime,
            listeningTime: baseEntry.listeningTime,
            status: baseEntry.status,
            isStale: baseEntry.isStale,
            lastDataUpdate: baseEntry.lastDataUpdate
        )

        // Schedule next timeline refresh
        // - Fresh data (< 5 min old): refresh in 5 min
        // - Moderate (5-30 min old): refresh in 10 min
        // - Stale (> 30 min old): refresh in 15 min
        // Main app will trigger immediate refresh via WidgetCenter when new data arrives
        let refreshInterval: TimeInterval
        if let lastUpdate = baseEntry.lastDataUpdate {
            let age = Date().timeIntervalSince(lastUpdate)
            if age < 300 {
                refreshInterval = 300  // 5 min
            } else if age < 1800 {
                refreshInterval = 600  // 10 min
            } else {
                refreshInterval = 900  // 15 min
            }
        } else {
            refreshInterval = 300  // Default to 5 min if no data
        }

        let refreshDate = now.addingTimeInterval(refreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    // MARK: - Data Fetching

    private func fetchTodayDose() -> DoseEntry? {
        // Try to get data from shared UserDefaults
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier) else {
            return nil
        }

        // FIXED: Check if data exists before reading (0.0 could be valid vs missing)
        guard defaults.object(forKey: "widget_lastUpdate") != nil else {
            return nil
        }

        let dosePercent = defaults.double(forKey: "widget_dosePercent")
        let remainingTime = defaults.double(forKey: "widget_remainingTime")
        let listeningTime = defaults.double(forKey: "widget_listeningTime")
        let lastUpdate = defaults.object(forKey: "widget_lastUpdate") as? Date

        // Check if data is from today
        if let lastUpdate = lastUpdate, Calendar.current.isDateInToday(lastUpdate) {
            // Data is stale if it's more than 30 minutes old
            let isStale = Date().timeIntervalSince(lastUpdate) > 1800

            return DoseEntry(
                date: .now,
                dosePercent: dosePercent,
                remainingTime: remainingTime,
                listeningTime: listeningTime,
                status: WidgetExposureStatus.from(dosePercent: dosePercent),
                isStale: isStale,
                lastDataUpdate: lastUpdate
            )
        }

        return nil
    }

    /// Fetches the last known dose data even if from a previous day
    /// Used as fallback to prevent sudden reset to 0% at day boundaries
    private func fetchLastKnownDose() -> DoseEntry? {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier) else {
            return nil
        }

        // Check if any data exists
        guard defaults.object(forKey: "widget_lastUpdate") != nil else {
            return nil
        }

        let lastUpdate = defaults.object(forKey: "widget_lastUpdate") as? Date

        // If data is from previous day, return it but marked as stale
        // This prevents the widget from suddenly showing 0% at midnight
        if let lastUpdate = lastUpdate, !Calendar.current.isDateInToday(lastUpdate) {
            // Return 0% for new day but preserve remaining time indicator
            // This indicates "fresh start" for today while not showing jarring 0%
            // until actual data arrives
            return DoseEntry(
                date: .now,
                dosePercent: 0,  // New day starts at 0%
                remainingTime: 8 * 3600,  // Reset to full safe time for new day
                listeningTime: 0,  // Reset listening time for new day
                status: .safe,
                isStale: true,  // Mark as stale since it's a new day
                lastDataUpdate: lastUpdate
            )
        }

        return nil
    }
}

// MARK: - Widget Data Updater (called from main app)

enum WidgetDataUpdater {
    static func updateWidgetData(
        dosePercent: Double,
        remainingTime: TimeInterval,
        listeningTime: TimeInterval = 0
    ) {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier) else {
            return
        }

        defaults.set(dosePercent, forKey: "widget_dosePercent")
        defaults.set(remainingTime, forKey: "widget_remainingTime")
        defaults.set(listeningTime, forKey: "widget_listeningTime")
        defaults.set(Date(), forKey: "widget_lastUpdate")

        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "BloopWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "BloopWidgetLockScreen")
    }
}
