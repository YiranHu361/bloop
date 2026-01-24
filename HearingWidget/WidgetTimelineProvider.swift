import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct DoseEntry: TimelineEntry {
    let date: Date
    let dosePercent: Double
    let remainingTime: TimeInterval
    let status: WidgetExposureStatus

    static let placeholder = DoseEntry(
        date: .now,
        dosePercent: 0,
        remainingTime: 8 * 3600,
        status: .safe
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

// MARK: - Timeline Provider

struct DoseTimelineProvider: TimelineProvider {
    // App group identifier for shared container
    static let appGroupIdentifier = "group.com.bloopapp.shared"

    func placeholder(in context: Context) -> DoseEntry {
        DoseEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) {
        let entry = fetchTodayDose() ?? DoseEntry.placeholder
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        let currentEntry = fetchTodayDose() ?? DoseEntry.placeholder

        // Refresh every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)

        let timeline = Timeline(entries: [currentEntry], policy: .after(refreshDate))
        completion(timeline)
    }

    // MARK: - Data Fetching

    private func fetchTodayDose() -> DoseEntry? {
        // Try to get data from shared UserDefaults
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            return nil
        }

        let dosePercent = defaults.double(forKey: "widget_dosePercent")
        let remainingTime = defaults.double(forKey: "widget_remainingTime")
        let lastUpdate = defaults.object(forKey: "widget_lastUpdate") as? Date

        // Check if data is from today
        if let lastUpdate = lastUpdate,
           Calendar.current.isDateInToday(lastUpdate),
           dosePercent > 0 || remainingTime > 0 {
            return DoseEntry(
                date: .now,
                dosePercent: dosePercent,
                remainingTime: remainingTime,
                status: WidgetExposureStatus.from(dosePercent: dosePercent)
            )
        }

        return nil
    }
}

// MARK: - Widget Data Updater (called from main app)

enum WidgetDataUpdater {
    static let appGroupIdentifier = "group.com.bloopapp.shared"

    static func updateWidgetData(dosePercent: Double, remainingTime: TimeInterval) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        defaults.set(dosePercent, forKey: "widget_dosePercent")
        defaults.set(remainingTime, forKey: "widget_remainingTime")
        defaults.set(Date(), forKey: "widget_lastUpdate")

        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "HearingWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "HearingWidgetLockScreen")
    }
}
