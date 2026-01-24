import Foundation
import SwiftData

/// User preferences and settings
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var doseModel: String
    var warningThreshold50Enabled: Bool
    var warningThreshold80Enabled: Bool
    var warningThreshold100Enabled: Bool
    var dailyReminderEnabled: Bool
    var dailyReminderTime: Date?
    var preset: String
    var lastModified: Date

    init(
        id: UUID = UUID(),
        doseModel: DoseModel = .niosh,
        warningThreshold50Enabled: Bool = true,
        warningThreshold80Enabled: Bool = true,
        warningThreshold100Enabled: Bool = true,
        dailyReminderEnabled: Bool = false,
        dailyReminderTime: Date? = nil,
        preset: SettingsPreset = .standard
    ) {
        self.id = id
        self.doseModel = doseModel.rawValue
        self.warningThreshold50Enabled = warningThreshold50Enabled
        self.warningThreshold80Enabled = warningThreshold80Enabled
        self.warningThreshold100Enabled = warningThreshold100Enabled
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
}

enum DoseModel: String, CaseIterable, Identifiable {
    case niosh = "niosh"
    case osha = "osha"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .niosh: return "NIOSH/WHO (Recommended)"
        case .osha: return "OSHA (Less Conservative)"
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

    var referenceDurationHours: Double { 8.0 }
}

enum SettingsPreset: String, CaseIterable, Identifiable {
    case teenSafe = "teen_safe"
    case standard = "standard"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .teenSafe: return "Teen-Safe"
        case .standard: return "Standard"
        case .custom: return "Custom"
        }
    }
}
