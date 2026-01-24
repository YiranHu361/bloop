import Foundation
import SwiftData

/// User preferences and settings for bloop. parental controls
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    
    // MARK: - Exposure Model
    var doseModel: String // DoseModel.rawValue
    
    // MARK: - Alert Thresholds (60/80/100)
    var warningThreshold50Enabled: Bool  // Using 50 field for 60% threshold
    var warningThreshold80Enabled: Bool
    var warningThreshold100Enabled: Bool
    
    // MARK: - Daily Limits
    var dailyExposureLimit: Int  // Percentage (80, 100, 120, etc.)
    var enforceLimit: Bool       // Whether to strongly warn at limit
    
    // MARK: - Quiet Hours
    var quietHoursEnabled: Bool
    var quietHoursStart: Date?   // e.g., 9:00 PM
    var quietHoursEnd: Date?     // e.g., 7:00 AM
    var quietHoursStrictMode: Bool // Send alerts during quiet hours
    
    // MARK: - Break Reminders
    var breakRemindersEnabled: Bool
    var breakIntervalMinutes: Int    // Remind every X minutes of listening
    var breakDurationMinutes: Int    // Suggested break duration
    var breakEnforcement: String     // BreakEnforcementLevel.rawValue
    
    // MARK: - Volume Alerts
    var instantVolumeAlerts: Bool    // Alert immediately when too loud
    var volumeAlertThresholdDB: Int  // dB level that triggers instant alert (e.g., 90)
    
    // MARK: - PIN Protection
    var pinProtectionEnabled: Bool
    var settingsPIN: String?         // Encrypted/hashed PIN
    
    // MARK: - Notification Style
    var notificationStyle: String    // NotificationStyle.rawValue
    var liveActivityEnabled: Bool    // Use iOS Live Activity
    var criticalAlertsEnabled: Bool  // iOS Critical Alerts (bypass DND)
    
    // MARK: - Weekly Reports
    var weeklyReportEnabled: Bool
    var weeklyReportDay: Int         // 1-7 (Sunday = 1)
    
    // MARK: - Kid-Friendly Mode
    var kidFriendlyMessages: Bool    // Use playful, encouraging language
    
    // MARK: - Metadata
    var dailyReminderEnabled: Bool
    var dailyReminderTime: Date?
    var preset: String // SettingsPreset.rawValue
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        doseModel: DoseModel = .niosh,
        warningThreshold50Enabled: Bool = true,
        warningThreshold80Enabled: Bool = true,
        warningThreshold100Enabled: Bool = true,
        dailyExposureLimit: Int = 100,
        enforceLimit: Bool = true,
        quietHoursEnabled: Bool = false,
        quietHoursStart: Date? = nil,
        quietHoursEnd: Date? = nil,
        quietHoursStrictMode: Bool = false,
        breakRemindersEnabled: Bool = true,
        breakIntervalMinutes: Int = 60,
        breakDurationMinutes: Int = 5,
        breakEnforcement: BreakEnforcementLevel = .gentle,
        instantVolumeAlerts: Bool = true,
        volumeAlertThresholdDB: Int = 90,
        pinProtectionEnabled: Bool = false,
        settingsPIN: String? = nil,
        notificationStyle: NotificationStyle = .prominent,
        liveActivityEnabled: Bool = true,
        criticalAlertsEnabled: Bool = false,
        weeklyReportEnabled: Bool = true,
        weeklyReportDay: Int = 1,
        kidFriendlyMessages: Bool = true,
        dailyReminderEnabled: Bool = false,
        dailyReminderTime: Date? = nil,
        preset: SettingsPreset = .standard
    ) {
        self.id = id
        self.doseModel = doseModel.rawValue
        self.warningThreshold50Enabled = warningThreshold50Enabled
        self.warningThreshold80Enabled = warningThreshold80Enabled
        self.warningThreshold100Enabled = warningThreshold100Enabled
        self.dailyExposureLimit = dailyExposureLimit
        self.enforceLimit = enforceLimit
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.quietHoursStrictMode = quietHoursStrictMode
        self.breakRemindersEnabled = breakRemindersEnabled
        self.breakIntervalMinutes = breakIntervalMinutes
        self.breakDurationMinutes = breakDurationMinutes
        self.breakEnforcement = breakEnforcement.rawValue
        self.instantVolumeAlerts = instantVolumeAlerts
        self.volumeAlertThresholdDB = volumeAlertThresholdDB
        self.pinProtectionEnabled = pinProtectionEnabled
        self.settingsPIN = settingsPIN
        self.notificationStyle = notificationStyle.rawValue
        self.liveActivityEnabled = liveActivityEnabled
        self.criticalAlertsEnabled = criticalAlertsEnabled
        self.weeklyReportEnabled = weeklyReportEnabled
        self.weeklyReportDay = weeklyReportDay
        self.kidFriendlyMessages = kidFriendlyMessages
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderTime = dailyReminderTime
        self.preset = preset.rawValue
        self.lastModified = Date()
    }
    
    var doseModelEnum: DoseModel {
        DoseModel(rawValue: doseModel) ?? .niosh
    }
    
    var presetEnum: SettingsPreset {
        SettingsPreset(rawValue: preset) ?? .standard
    }
    
    var breakEnforcementEnum: BreakEnforcementLevel {
        BreakEnforcementLevel(rawValue: breakEnforcement) ?? .gentle
    }
    
    var notificationStyleEnum: NotificationStyle {
        NotificationStyle(rawValue: notificationStyle) ?? .prominent
    }
}

// MARK: - Dose Calculation Model

enum DoseModel: String, CaseIterable, Identifiable {
    case niosh = "niosh"  // 85 dB, 3 dB exchange rate
    case osha = "osha"    // 90 dB, 5 dB exchange rate
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .niosh: return "WHO/NIOSH (Recommended)"
        case .osha: return "OSHA (Less Conservative)"
        }
    }
    
    var description: String {
        switch self {
        case .niosh:
            return "85 dB for 8 hours. Every 3 dB increase halves safe time. Recommended by WHO."
        case .osha:
            return "90 dB for 8 hours. Every 5 dB increase halves safe time. US workplace standard."
        }
    }
    
    var referenceLevel: Double {
        switch self {
        case .niosh: return 85.0
        case .osha: return 90.0
        }
    }
    
    var exchangeRate: Double {
        switch self {
        case .niosh: return 3.0
        case .osha: return 5.0
        }
    }
    
    var referenceDurationHours: Double {
        return 8.0
    }
}

// MARK: - Settings Presets

enum SettingsPreset: String, CaseIterable, Identifiable {
    case kidSafe = "kid_safe"
    case standard = "standard"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .kidSafe: return "Kid-Safe (Strict)"
        case .standard: return "Standard"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .kidSafe:
            return "Stricter limits and more frequent alerts for younger children."
        case .standard:
            return "WHO-recommended safe listening guidelines."
        case .custom:
            return "Customize your own thresholds and preferences."
        }
    }
}

// MARK: - Break Enforcement Level

enum BreakEnforcementLevel: String, CaseIterable, Identifiable {
    case off = "off"
    case gentle = "gentle"
    case moderate = "moderate"
    case strict = "strict"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .gentle: return "Gentle Suggestions"
        case .moderate: return "Persistent Reminders"
        case .strict: return "Strong Alerts"
        }
    }
    
    var description: String {
        switch self {
        case .off: return "No break reminders"
        case .gentle: return "Occasional friendly suggestions"
        case .moderate: return "Regular reminders that repeat"
        case .strict: return "Prominent alerts until break is taken"
        }
    }
    
    var icon: String {
        switch self {
        case .off: return "bell.slash"
        case .gentle: return "leaf"
        case .moderate: return "bell"
        case .strict: return "bell.badge"
        }
    }
}

// MARK: - Notification Style

enum NotificationStyle: String, CaseIterable, Identifiable {
    case minimal = "minimal"
    case standard = "standard"
    case prominent = "prominent"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .standard: return "Standard"
        case .prominent: return "Prominent (Recommended)"
        }
    }
    
    var description: String {
        switch self {
        case .minimal: return "Small, quiet notifications"
        case .standard: return "Normal iOS notifications"
        case .prominent: return "Large banners with sound"
        }
    }
    
    var icon: String {
        switch self {
        case .minimal: return "bell.slash"
        case .standard: return "bell"
        case .prominent: return "bell.badge.fill"
        }
    }
}
