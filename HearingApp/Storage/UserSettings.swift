import Foundation
import SwiftData

/// User preferences and settings
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var doseModel: String // DoseModel.rawValue
    var warningThreshold50Enabled: Bool
    var warningThreshold80Enabled: Bool
    var warningThreshold100Enabled: Bool
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

/// Dose calculation model
enum DoseModel: String, CaseIterable, Identifiable {
    case niosh = "niosh"  // 85 dB, 3 dB exchange rate
    case osha = "osha"    // 90 dB, 5 dB exchange rate
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .niosh: return "NIOSH/WHO (Recommended)"
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

/// Settings presets for quick configuration
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
    
    var description: String {
        switch self {
        case .teenSafe:
            return "More conservative thresholds, designed for younger users."
        case .standard:
            return "WHO-recommended safe listening guidelines."
        case .custom:
            return "Customize your own thresholds and preferences."
        }
    }
}
