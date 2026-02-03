import Foundation
import SwiftUI
import SwiftData

/// ViewModel for Settings view - bloop. parent control center
@MainActor
final class SettingsViewModel: ObservableObject {
    
    // MARK: - Alerts & Nudges (60/80/100 thresholds)
    @Published var notify60Percent: Bool = true
    @Published var notify80Percent: Bool = true
    @Published var notify100Percent: Bool = true
    
    // MARK: - Exposure Model
    @Published var doseModel: DoseModel = .niosh
    
    // MARK: - Daily Limits
    @Published var dailyExposureLimit: Int = 100
    @Published var enforceLimit: Bool = true
    
    // MARK: - Quiet Hours
    @Published var quietHoursEnabled: Bool = false
    @Published var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    @Published var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @Published var quietHoursStrictMode: Bool = false
    
    // MARK: - Break Reminders
    @Published var breakRemindersEnabled: Bool = true
    @Published var breakIntervalMinutes: Int = 60
    @Published var breakDurationMinutes: Int = 5
    @Published var breakEnforcement: BreakEnforcementLevel = .gentle
    
    // MARK: - Volume Alerts
    @Published var instantVolumeAlerts: Bool = true
    @Published var volumeAlertThresholdDB: Int = 90
    
    // MARK: - PIN Protection
    @Published var pinProtectionEnabled: Bool = false
    @Published var settingsPIN: String = ""
    @Published var isPINVerified: Bool = false
    
    // MARK: - Notification Style
    @Published var notificationStyle: NotificationStyle = .prominent
    @Published var liveActivityEnabled: Bool = true
    @Published var criticalAlertsEnabled: Bool = false
    
    // MARK: - Weekly Reports
    @Published var weeklyReportEnabled: Bool = true
    @Published var weeklyReportDay: Int = 1
    
    // MARK: - Kid-Friendly Mode
    @Published var kidFriendlyMessages: Bool = true
    
    // MARK: - Data Storage
    @Published var historyDuration: Int = 30 // days, 0 = forever
    
    private var modelContext: ModelContext?
    private struct AINotificationPayload: Codable {
        let title: String
        let body: String
    }
    
    // MARK: - Available Options
    
    static let dailyLimitOptions = [80, 90, 100, 110, 120]
    static let breakIntervalOptions = [30, 45, 60, 90, 120]
    static let breakDurationOptions = [3, 5, 10, 15]
    static let volumeThresholdOptions = [85, 90, 95, 100]
    static let weekdayOptions = [
        (1, "Sunday"), (2, "Monday"), (3, "Tuesday"), 
        (4, "Wednesday"), (5, "Thursday"), (6, "Friday"), (7, "Saturday")
    ]
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSettings()
    }
    
    private func loadSettings() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(descriptor)
            
            if let userSettings = settings.first {
                doseModel = userSettings.doseModelEnum
                notify60Percent = userSettings.warningThreshold50Enabled
                notify80Percent = userSettings.warningThreshold80Enabled
                notify100Percent = userSettings.warningThreshold100Enabled
                
                dailyExposureLimit = userSettings.dailyExposureLimit
                enforceLimit = userSettings.enforceLimit
                
                quietHoursEnabled = userSettings.quietHoursEnabled
                if let start = userSettings.quietHoursStart {
                    quietHoursStart = start
                }
                if let end = userSettings.quietHoursEnd {
                    quietHoursEnd = end
                }
                quietHoursStrictMode = userSettings.quietHoursStrictMode
                
                breakRemindersEnabled = userSettings.breakRemindersEnabled
                breakIntervalMinutes = userSettings.breakIntervalMinutes
                breakDurationMinutes = userSettings.breakDurationMinutes
                breakEnforcement = userSettings.breakEnforcementEnum
                
                instantVolumeAlerts = userSettings.instantVolumeAlerts
                volumeAlertThresholdDB = userSettings.volumeAlertThresholdDB
                
                pinProtectionEnabled = userSettings.pinProtectionEnabled
                settingsPIN = userSettings.settingsPIN ?? ""
                
                notificationStyle = userSettings.notificationStyleEnum
                liveActivityEnabled = userSettings.liveActivityEnabled
                criticalAlertsEnabled = userSettings.criticalAlertsEnabled
                
                weeklyReportEnabled = userSettings.weeklyReportEnabled
                weeklyReportDay = userSettings.weeklyReportDay
                
                kidFriendlyMessages = userSettings.kidFriendlyMessages
            }
        } catch {
            // Error loading settings
        }
    }
    
    func saveSettings() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(descriptor)
            
            if let userSettings = settings.first {
                updateSettings(userSettings)
            } else {
                let newSettings = createNewSettings()
                context.insert(newSettings)
            }
            
            try context.save()
        } catch {
            // Error saving settings
        }
    }
    
    private func updateSettings(_ settings: UserSettings) {
        settings.doseModel = doseModel.rawValue
        settings.warningThreshold50Enabled = notify60Percent
        settings.warningThreshold80Enabled = notify80Percent
        settings.warningThreshold100Enabled = notify100Percent
        
        settings.dailyExposureLimit = dailyExposureLimit
        settings.enforceLimit = enforceLimit
        
        settings.quietHoursEnabled = quietHoursEnabled
        settings.quietHoursStart = quietHoursStart
        settings.quietHoursEnd = quietHoursEnd
        settings.quietHoursStrictMode = quietHoursStrictMode
        
        settings.breakRemindersEnabled = breakRemindersEnabled
        settings.breakIntervalMinutes = breakIntervalMinutes
        settings.breakDurationMinutes = breakDurationMinutes
        settings.breakEnforcement = breakEnforcement.rawValue
        
        settings.instantVolumeAlerts = instantVolumeAlerts
        settings.volumeAlertThresholdDB = volumeAlertThresholdDB
        
        settings.pinProtectionEnabled = pinProtectionEnabled
        settings.settingsPIN = settingsPIN.isEmpty ? nil : settingsPIN
        
        settings.notificationStyle = notificationStyle.rawValue
        settings.liveActivityEnabled = liveActivityEnabled
        settings.criticalAlertsEnabled = criticalAlertsEnabled
        
        settings.weeklyReportEnabled = weeklyReportEnabled
        settings.weeklyReportDay = weeklyReportDay
        
        settings.kidFriendlyMessages = kidFriendlyMessages
        
        settings.lastModified = Date()
    }
    
    private func createNewSettings() -> UserSettings {
        UserSettings(
            doseModel: doseModel,
            warningThreshold50Enabled: notify60Percent,
            warningThreshold80Enabled: notify80Percent,
            warningThreshold100Enabled: notify100Percent,
            dailyExposureLimit: dailyExposureLimit,
            enforceLimit: enforceLimit,
            quietHoursEnabled: quietHoursEnabled,
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd,
            quietHoursStrictMode: quietHoursStrictMode,
            breakRemindersEnabled: breakRemindersEnabled,
            breakIntervalMinutes: breakIntervalMinutes,
            breakDurationMinutes: breakDurationMinutes,
            breakEnforcement: breakEnforcement,
            instantVolumeAlerts: instantVolumeAlerts,
            volumeAlertThresholdDB: volumeAlertThresholdDB,
            pinProtectionEnabled: pinProtectionEnabled,
            settingsPIN: settingsPIN.isEmpty ? nil : settingsPIN,
            notificationStyle: notificationStyle,
            liveActivityEnabled: liveActivityEnabled,
            criticalAlertsEnabled: criticalAlertsEnabled,
            weeklyReportEnabled: weeklyReportEnabled,
            weeklyReportDay: weeklyReportDay,
            kidFriendlyMessages: kidFriendlyMessages
        )
    }
    
    // MARK: - PIN Verification
    
    func verifyPIN(_ enteredPIN: String) -> Bool {
        guard pinProtectionEnabled else { return true }
        let isValid = enteredPIN == settingsPIN
        isPINVerified = isValid
        return isValid
    }
    
    func setPIN(_ newPIN: String) {
        settingsPIN = newPIN
        pinProtectionEnabled = !newPIN.isEmpty
        saveSettings()
    }
    
    func removePIN() {
        settingsPIN = ""
        pinProtectionEnabled = false
        isPINVerified = false
        saveSettings()
    }

    // MARK: - Debug AI Notification

    func sendAINotificationTest(context: ModelContext) async {
        // Ensure we have permission (user-initiated tap is a good time to prompt)
        await NotificationService.shared.requestAuthorization()
        await NotificationService.shared.checkAuthorizationStatus()

        guard NotificationService.shared.isAuthorized else {
            // If notifications are denied, we can't deliver
            AppLogger.logWarning("Notifications not authorized — unable to send AI note", context: "AINotification", logger: AppLogger.notifications)
            return
        }

        // If Gemini isn't configured, send a default test notification so the button always works.
        guard APIConfig.isGeminiConfigured else {
            await NotificationService.shared.sendAgentNotification(
                title: "Hearing Check",
                body: "Keep volumes comfortable for safe listening."
            )
            return
        }

        let dosePercent = fetchTodayDosePercent(context: context)
        let prompt = """
        You are generating a short hearing safety notification.
        Return ONLY valid JSON with fields: title, body.
        Keep it under 20 words total.
        Try to vary the wording while staying supportive and clear.

        Current state:
        - dosePercent: \(dosePercent)

        Example:
        {"title":"Hearing Check","body":"Keep volumes comfortable for safe listening."}
        """

        do {
            let response = try await GeminiService.shared.generateText(
                prompt: prompt,
                temperature: 0.5,
                maxOutputTokens: 120
            )

            AppLogger.logDebug("AI notify response: \(response)", context: "AINotification", logger: AppLogger.ai)

            let payload = decodeAINotification(from: response)
            let title = payload?.title ?? "Hearing Check"
            let body = payload?.body ?? "Keep volumes comfortable for safe listening."
            await NotificationService.shared.sendAgentNotification(title: title, body: body)
        } catch {
            AppLogger.logError(error, context: "AINotification", logger: AppLogger.ai)
            await NotificationService.shared.sendAgentNotification(
                title: "Hearing Check",
                body: "Keep volumes comfortable for safe listening."
            )
        }
    }

    private func fetchTodayDosePercent(context: ModelContext) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month, .day], from: today)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return 0
        }

        let predicate = #Predicate<DailyDose> { dose in
            dose.year == year &&
            dose.month == month &&
            dose.day == day
        }

        let descriptor = FetchDescriptor<DailyDose>(predicate: predicate)
        let doses = (try? context.fetch(descriptor)) ?? []
        return Int(doses.first?.dosePercent ?? 0)
    }

    private func decodeAINotification(from response: String) -> AINotificationPayload? {
        let cleaned = stripCodeFences(response)
        if let direct = decodeAINotificationJSON(cleaned) {
            return direct
        }

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return nil
        }

        let jsonSlice = cleaned[start...end]
        return decodeAINotificationJSON(String(jsonSlice))
    }

    private func decodeAINotificationJSON(_ json: String) -> AINotificationPayload? {
        do {
            let data = Data(json.utf8)
            return try JSONDecoder().decode(AINotificationPayload.self, from: data)
        } catch {
            return nil
        }
    }

    private func stripCodeFences(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Preset Application
    
    func applyPreset(_ preset: SettingsPreset) {
        switch preset {
        case .kidSafe:
            dailyExposureLimit = 80
            enforceLimit = true
            notify60Percent = true
            notify80Percent = true
            notify100Percent = true
            breakRemindersEnabled = true
            breakIntervalMinutes = 45
            breakEnforcement = .moderate
            instantVolumeAlerts = true
            volumeAlertThresholdDB = 85
            notificationStyle = .prominent
            liveActivityEnabled = true
            kidFriendlyMessages = true
            
        case .standard:
            dailyExposureLimit = 100
            enforceLimit = true
            notify60Percent = true
            notify80Percent = true
            notify100Percent = true
            breakRemindersEnabled = true
            breakIntervalMinutes = 60
            breakEnforcement = .gentle
            instantVolumeAlerts = true
            volumeAlertThresholdDB = 90
            notificationStyle = .prominent
            liveActivityEnabled = true
            kidFriendlyMessages = true
            
        case .custom:
            // Don't change anything, let user customize
            break
        }
        
        saveSettings()
    }
    
    // MARK: - Debug Functions
    
    func generateSampleData(context: ModelContext) async {
        await resetAgentHistory(context: context)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for daysAgo in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            
            let dosePercent: Double
            if daysAgo == 0 {
                // dosePercent = Double.random(in: 20...80)
                dosePercent = 89
            } else {
                dosePercent = Double.random(in: 20...120)
            }
            let avgLevel = Double.random(in: 65...95)
            let peakLevel = avgLevel + Double.random(in: 5...15)
            let exposureTime = Double.random(in: 1800...14400)
            
            let dose = DailyDose(
                date: date,
                dosePercent: dosePercent,
                totalExposureSeconds: exposureTime,
                averageLevelDBASPL: avgLevel,
                peakLevelDBASPL: peakLevel,
                timeAbove85dB: dosePercent > 50 ? exposureTime * 0.3 : 0,
                timeAbove90dB: dosePercent > 80 ? exposureTime * 0.1 : 0
            )
            
            context.insert(dose)
        }
        
        for hourAgo in 0..<8 {
            guard let startTime = calendar.date(byAdding: .hour, value: -hourAgo, to: Date()),
                  let endTime = calendar.date(byAdding: .minute, value: 30, to: startTime) else { continue }
            
            let sample = ExposureSample(
                healthKitUUID: "debug-sample-\(UUID().uuidString)",
                startDate: startTime,
                endDate: endTime,
                levelDBASPL: Double.random(in: 60...95)
            )
            context.insert(sample)
        }

        // TEMP: add recent loud samples to force listening=true in debug
        let now = Date()
        let recentOffsets: [(start: Int, end: Int, level: Double)] = [
            (-6, -4, 92),
            (-4, -2, 95),
            (-2, 0, 90)
        ]
        for offset in recentOffsets {
            if let recentStart = calendar.date(byAdding: .minute, value: offset.start, to: now),
               let recentEnd = calendar.date(byAdding: .minute, value: offset.end, to: now) {
                let sample = ExposureSample(
                    healthKitUUID: "debug-active-\(UUID().uuidString)",
                    startDate: recentStart,
                    endDate: recentEnd,
                    levelDBASPL: offset.level
                )
                context.insert(sample)
            }
        }
        
        try? context.save()
        NotificationCenter.default.post(name: .healthKitDataUpdated, object: nil)
    }
    
    func clearAllData(context: ModelContext) async {
        do {
            try context.delete(model: DailyDose.self)
            try context.delete(model: ExposureSample.self)
            try context.delete(model: ExposureEvent.self)
            try context.delete(model: SyncState.self)
            try context.save()
        } catch {
            // Error clearing data
        }
    }

    // MARK: - Debug Agent Reset

    func resetAgentHistory(context: ModelContext) async {
        do {
            try context.delete(model: AgentInterventionEvent.self)
            try context.delete(model: AgentComplianceEvent.self)
            try context.delete(model: AgentState.self)
            try context.save()
        } catch {
            // Error resetting agent history
        }
    }
}

