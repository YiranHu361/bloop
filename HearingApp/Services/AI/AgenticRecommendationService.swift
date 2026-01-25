import Foundation
import SwiftData

/// Agent loop that decides when to notify or suggest breaks based on live listening context.
@MainActor
final class AgenticRecommendationService {
    static let shared = AgenticRecommendationService()

    private let evaluationCooldown: TimeInterval = 60
    private let interventionCooldown: TimeInterval = 10 * 60
    private let complianceWindow: TimeInterval = 30 * 60
    private let breakDetectionThreshold: TimeInterval = 10 * 60
    private let sessionGap: TimeInterval = 5 * 60
    private let volumeDropThresholdDB: Double = 3
    static let recentSampleWindowSeconds: TimeInterval = 10 * 60
    private let syncCooldown: TimeInterval = 10 * 60
    private let dailyLimitMin = 70
    private let dailyLimitMax = 100
    private let volumeThresholdMin = 60
    private let volumeThresholdMax = 95
    private let ignoreWindow: TimeInterval = 6 * 60 * 60
    private let ignoreThreshold = 3

    private init() {}

    func evaluateIfNeeded(
        modelContext: ModelContext,
        dose: DailyDose?,
        samples: [ExposureSample],
        aiInsight: AIInsight,
        currentLevelDB: Double?,
        doseModel: DoseModel
    ) async {
        let now = Date()
        let state = fetchOrCreateAgentState(context: modelContext)
        let settings = fetchUserSettings(context: modelContext)

        if dose == nil {
            print("🤖 AI gate: missing dose")
            return
        }

        if let lastEvaluatedAt = state.lastEvaluatedAt,
           now.timeIntervalSince(lastEvaluatedAt) < evaluationCooldown {
            print("🤖 AI gate: evaluation cooldown")
            return
        }

        if isInQuietHours(settings: settings, now: now), !settings.quietHoursStrictMode {
            print("🤖 AI gate: quiet hours")
            state.lastEvaluatedAt = now
            try? modelContext.save()
            return
        }

        let isActivelyListening = aiInsight.isActivelyListening
        let isRecent = isRecentSample(samples: samples, now: now)
        let isHeadphoneOutput = AudioRouteMonitor.shared.currentOutputType.isHeadphoneType

        if !isActivelyListening || !isRecent || !isHeadphoneOutput {
            print("🤖 AI gate: listening=\(isActivelyListening) recent=\(isRecent) headphones=\(isHeadphoneOutput)")
            state.lastEvaluatedAt = now
            await updateComplianceIfNeeded(
                modelContext: modelContext,
                samples: samples,
                now: now
            )
            try? modelContext.save()
            return
        }

        if let lastInterventionAt = state.lastInterventionAt,
           now.timeIntervalSince(lastInterventionAt) < interventionCooldown {
            print("🤖 AI gate: intervention cooldown")
            state.lastEvaluatedAt = now
            await updateComplianceIfNeeded(
                modelContext: modelContext,
                samples: samples,
                now: now
            )
            try? modelContext.save()
            return
        }

        state.lastEvaluatedAt = now
        let dose = dose!

        await updateHealthKitStatusIfNeeded(modelContext: modelContext, now: now)

        let sessionDuration = currentSessionDuration(samples: samples)
        let sessionId = sessionIdentifier(from: samples)
        let suppressNotifications = shouldSuppressNotifications(
            modelContext: modelContext,
            now: now
        )

        let geminiConfigured = APIConfig.isGeminiConfigured
        print("🤖 AI config: geminiConfigured=\(geminiConfigured) suppressNotifications=\(suppressNotifications)")
        if geminiConfigured {
            if let decision = await fetchAIDecision(
                dose: dose,
                settings: settings,
                insight: aiInsight,
                currentLevelDB: currentLevelDB,
                sessionDuration: sessionDuration,
                suppressNotifications: suppressNotifications
            ) {
                let sessionMinutes = sessionDuration.map { Int($0 / 60) } ?? 0
                let handled = await applyDecision(
                    decision,
                    modelContext: modelContext,
                    settings: settings,
                    dose: dose,
                    insight: aiInsight,
                    sessionId: sessionId,
                    sessionMinutes: sessionMinutes,
                    suppressNotifications: suppressNotifications,
                    now: now
                )

                if handled {
                    try? modelContext.save()
                    return
                }
            }
        }

        if await maybeTriggerHealthKitSync(
            modelContext: modelContext,
            state: state,
            now: now
        ) {
            try? modelContext.save()
        }

        if !suppressNotifications,
           dose.dosePercent >= Double(settings.dailyExposureLimit) {
            await NotificationService.shared.sendActionableNotification(
                dosePercent: dose.dosePercent,
                currentLevel: currentLevelDB,
                doseModel: doseModel
            )
            recordIntervention(
                context: modelContext,
                trigger: "limit_reached",
                action: "notify_limit",
                message: "limit_reached",
                dose: dose,
                insight: aiInsight,
                sessionId: sessionId
            )
            state.lastInterventionAt = now
        } else if !suppressNotifications,
                  let eta = aiInsight.etaToLimit, eta <= 30 * 60 {
            await NotificationService.shared.sendActionableNotification(
                dosePercent: dose.dosePercent,
                currentLevel: currentLevelDB,
                doseModel: doseModel
            )
            recordIntervention(
                context: modelContext,
                trigger: "eta_warning",
                action: "notify_eta",
                message: "eta_warning",
                dose: dose,
                insight: aiInsight,
                sessionId: sessionId
            )
            state.lastInterventionAt = now
        } else if !suppressNotifications,
                  settings.breakRemindersEnabled,
                  let sessionDuration = sessionDuration,
                  sessionDuration >= TimeInterval(settings.breakIntervalMinutes * 60),
                  shouldSendBreakReminder(state: state, now: now, intervalMinutes: settings.breakIntervalMinutes) {
            await NotificationService.shared.sendBreakReminder(
                sessionMinutes: Int(sessionDuration / 60),
                breakMinutes: settings.breakDurationMinutes,
                cooldownSeconds: TimeInterval(settings.breakIntervalMinutes * 60)
            )
            recordIntervention(
                context: modelContext,
                trigger: "break_interval",
                action: "notify_break",
                message: "break_reminder",
                dose: dose,
                insight: aiInsight,
                sessionId: sessionId
            )
            state.lastBreakReminderAt = now
            state.lastInterventionAt = now
        } else if !suppressNotifications,
                  settings.instantVolumeAlerts,
                  let currentLevelDB = currentLevelDB,
                  currentLevelDB >= Double(settings.volumeAlertThresholdDB) {
            await NotificationService.shared.sendVolumeSuggestion(
                currentLevel: currentLevelDB,
                currentDosePercent: dose.dosePercent,
                doseModel: doseModel
            )
            recordIntervention(
                context: modelContext,
                trigger: "volume_alert",
                action: "suggest_volume",
                message: "volume_alert",
                dose: dose,
                insight: aiInsight,
                sessionId: sessionId
            )
            state.lastInterventionAt = now
        }

        state.lastDosePercent = dose.dosePercent
        state.lastBurnRatePerHour = aiInsight.burnRatePerHour
        state.lastEtaSeconds = aiInsight.etaToLimit

        await updateComplianceIfNeeded(
            modelContext: modelContext,
            samples: samples,
            now: now
        )

        try? modelContext.save()
    }

    private struct AgentDecision: Codable {
        let action: String
        let title: String?
        let body: String?
        let triggerSync: Bool?
        let setDailyLimit: Int?
        let setVolumeThresholdDB: Int?
        let breakMinutes: Int?
        let reason: String?
    }

    private func fetchAIDecision(
        dose: DailyDose,
        settings: UserSettings,
        insight: AIInsight,
        currentLevelDB: Double?,
        sessionDuration: TimeInterval?,
        suppressNotifications: Bool
    ) async -> AgentDecision? {
        let prompt = buildAgentPrompt(
            dose: dose,
            settings: settings,
            insight: insight,
            currentLevelDB: currentLevelDB,
            sessionDuration: sessionDuration,
            suppressNotifications: suppressNotifications
        )

        do {
            let response = try await GeminiService.shared.generateText(
                prompt: prompt,
                temperature: 0.2,
                maxOutputTokens: 220
            )
            // TEMP: decision logging for debugging
            print("🤖 AI decision raw: \(response)")
            let decision = parseDecision(from: response)
            if let decision {
                print("🤖 AI decision parsed: action=\(decision.action) reason=\(decision.reason ?? "none")")
            } else {
                print("🤖 AI decision parse failed")
            }
            return decision
        } catch {
            return nil
        }
    }

    private func buildAgentPrompt(
        dose: DailyDose,
        settings: UserSettings,
        insight: AIInsight,
        currentLevelDB: Double?,
        sessionDuration: TimeInterval?,
        suppressNotifications: Bool
    ) -> String {
        let sessionMinutes = sessionDuration.map { Int($0 / 60) } ?? 0
        let level = currentLevelDB.map { String(format: "%.1f", $0) } ?? "unknown"
        let etaMinutes = insight.etaToLimit.map { Int($0 / 60) }
        let quietHours = settings.quietHoursEnabled && !settings.quietHoursStrictMode

        return """
        You are a safety-first hearing assistant deciding the next action.
        Be helpful, concise, and supportive. Avoid nagging or shaming language.
        Prefer the least intrusive action that still protects hearing.
        Output ONLY valid JSON.

        Current state:
        - dosePercent: \(Int(dose.dosePercent))
        - burnRatePerHour: \(String(format: "%.1f", insight.burnRatePerHour))
        - etaMinutes: \(etaMinutes?.description ?? "null")
        - isActivelyListening: \(insight.isActivelyListening)
        - currentLevelDB: \(level)
        - sessionMinutes: \(sessionMinutes)
        - dailyExposureLimit: \(settings.dailyExposureLimit)
        - volumeAlertThresholdDB: \(settings.volumeAlertThresholdDB)
        - quietHoursActive: \(quietHours)
        - suppressNotifications: \(suppressNotifications)

        Guardrails:
        - Do NOT send notifications when quietHoursActive is true.
        - At most one notification per 10 minutes; prefer fewer notifications and only when necessary.
        - Daily limit can be adjusted only within \(dailyLimitMin)-\(dailyLimitMax).
        - Volume alert threshold can be adjusted only within \(volumeThresholdMin)-\(volumeThresholdMax).
        - Actions allowed: "none", "notify", "break", "sync", "adjust_settings".

        JSON schema:
        {
          "action": "none|notify|break|sync|adjust_settings",
          "title": "string or null",
          "body": "string or null",
          "triggerSync": true|false|null,
          "setDailyLimit": number or null,
          "setVolumeThresholdDB": number or null,
          "breakMinutes": number or null,
          "reason": "string or null"
        }

        Respond with JSON only.
        """
    }

    private func parseDecision(from response: String) -> AgentDecision? {
        let cleaned = stripCodeFences(response)
        if let direct = decodeDecision(from: cleaned) {
            return direct
        }

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return nil
        }

        let jsonSlice = cleaned[start...end]
        return decodeDecision(from: String(jsonSlice))
    }

    private func decodeDecision(from json: String) -> AgentDecision? {
        do {
            let data = Data(json.utf8)
            return try JSONDecoder().decode(AgentDecision.self, from: data)
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

    private func applyDecision(
        _ decision: AgentDecision,
        modelContext: ModelContext,
        settings: UserSettings,
        dose: DailyDose,
        insight: AIInsight,
        sessionId: String?,
        sessionMinutes: Int,
        suppressNotifications: Bool,
        now: Date
    ) async -> Bool {
        let quietHoursBlocked = settings.quietHoursEnabled && !settings.quietHoursStrictMode

        switch decision.action {
        case "notify":
            if quietHoursBlocked || suppressNotifications { return true }
            if let title = decision.title, let body = decision.body {
                // TEMP: log AI notification action
                print("🤖 AI action: notify | title=\(title) | reason=\(decision.reason ?? "none")")
                await NotificationService.shared.sendAgentNotification(title: title, body: body)
                recordIntervention(
                    context: modelContext,
                    trigger: "ai_notify",
                    action: "notify",
                    message: decision.reason ?? "ai_notify",
                    dose: dose,
                    insight: insight,
                    sessionId: sessionId
                )
                if let state = try? modelContext.fetch(FetchDescriptor<AgentState>()).first {
                    state.lastInterventionAt = now
                }
                return true
            }
            return false
        case "break":
            if quietHoursBlocked || suppressNotifications { return true }
            let breakMinutes = decision.breakMinutes ?? settings.breakDurationMinutes
            // TEMP: log AI break action
            print("🤖 AI action: break | minutes=\(breakMinutes) | reason=\(decision.reason ?? "none")")
            await NotificationService.shared.sendBreakReminder(
                sessionMinutes: sessionMinutes,
                breakMinutes: breakMinutes,
                cooldownSeconds: TimeInterval(settings.breakIntervalMinutes * 60)
            )
            recordIntervention(
                context: modelContext,
                trigger: "ai_break",
                action: "break",
                message: decision.reason ?? "ai_break",
                dose: dose,
                insight: insight,
                sessionId: sessionId
            )
            if let state = try? modelContext.fetch(FetchDescriptor<AgentState>()).first {
                state.lastInterventionAt = now
            }
            return true
        case "sync":
            if decision.triggerSync == true {
                // TEMP: log AI sync action
                print("🤖 AI action: sync | reason=\(decision.reason ?? "none")")
                _ = await maybeTriggerHealthKitSync(modelContext: modelContext, state: fetchOrCreateAgentState(context: modelContext), now: now)
                return true
            }
            return false
        case "adjust_settings":
            var changed = false
            if let newLimit = decision.setDailyLimit {
                let clamped = clamp(newLimit, min: dailyLimitMin, max: dailyLimitMax)
                if clamped != settings.dailyExposureLimit {
                    settings.dailyExposureLimit = clamped
                    changed = true
                }
            }
            if let newThreshold = decision.setVolumeThresholdDB {
                let clamped = clamp(newThreshold, min: volumeThresholdMin, max: volumeThresholdMax)
                if clamped != settings.volumeAlertThresholdDB {
                    settings.volumeAlertThresholdDB = clamped
                    changed = true
                }
            }
            if changed {
                // TEMP: log AI adjust action
                print("🤖 AI action: adjust_settings | dailyLimit=\(settings.dailyExposureLimit) | volumeThreshold=\(settings.volumeAlertThresholdDB) | reason=\(decision.reason ?? "none")")
                settings.lastModified = Date()
                recordIntervention(
                    context: modelContext,
                    trigger: "ai_adjust",
                    action: "adjust_settings",
                    message: decision.reason ?? "ai_adjust",
                    dose: dose,
                    insight: insight,
                    sessionId: sessionId
                )
                return true
            }
            return false
        default:
            return false
        }
    }

    private func shouldSuppressNotifications(
        modelContext: ModelContext,
        now: Date
    ) -> Bool {
        let cutoff = now.addingTimeInterval(-ignoreWindow)
        let predicate = #Predicate<AgentInterventionEvent> { event in
            event.timestamp >= cutoff && event.complianceOutcome == "no_change"
        }
        let descriptor = FetchDescriptor<AgentInterventionEvent>(predicate: predicate)
        let ignoredCount = (try? modelContext.fetch(descriptor).count) ?? 0
        return ignoredCount >= ignoreThreshold
    }

    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }

    private func fetchOrCreateAgentState(context: ModelContext) -> AgentState {
        let descriptor = FetchDescriptor<AgentState>()
        let existing = try? context.fetch(descriptor).first
        if let existing {
            return existing
        }
        let state = AgentState()
        context.insert(state)
        return state
    }

    private func fetchUserSettings(context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? context.fetch(descriptor).first {
            return settings
        }
        return UserSettings()
    }

    private func isInQuietHours(settings: UserSettings, now: Date) -> Bool {
        guard settings.quietHoursEnabled,
              let start = settings.quietHoursStart,
              let end = settings.quietHoursEnd else {
            return false
        }
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)

        guard let nowMinutes = minutes(from: nowComponents),
              let startMinutes = minutes(from: startComponents),
              let endMinutes = minutes(from: endComponents) else {
            return false
        }

        if startMinutes <= endMinutes {
            return nowMinutes >= startMinutes && nowMinutes <= endMinutes
        }
        return nowMinutes >= startMinutes || nowMinutes <= endMinutes
    }

    private func minutes(from components: DateComponents) -> Int? {
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return hour * 60 + minute
    }

    private func isRecentSample(samples: [ExposureSample], now: Date) -> Bool {
        guard let last = samples.last else { return false }
        let lastDate = last.endDate
        return now.timeIntervalSince(lastDate) <= Self.recentSampleWindowSeconds
    }

    private func currentSessionDuration(samples: [ExposureSample]) -> TimeInterval? {
        guard !samples.isEmpty else { return nil }
        let ordered = samples.sorted { $0.startDate < $1.startDate }
        guard let lastSample = ordered.last else { return nil }
        var sessionStart = lastSample.startDate

        for sample in ordered.dropLast().reversed() {
            let gap = sessionStart.timeIntervalSince(sample.endDate)
            if gap <= sessionGap {
                sessionStart = sample.startDate
            } else {
                break
            }
        }

        return max(0, lastSample.endDate.timeIntervalSince(sessionStart))
    }

    private func sessionIdentifier(from samples: [ExposureSample]) -> String? {
        guard let last = samples.last else { return nil }
        return ISO8601DateFormatter().string(from: last.startDate)
    }

    private func shouldSendBreakReminder(state: AgentState, now: Date, intervalMinutes: Int) -> Bool {
        guard let lastBreak = state.lastBreakReminderAt else { return true }
        let cooldown = TimeInterval(intervalMinutes * 60)
        return now.timeIntervalSince(lastBreak) >= cooldown
    }

    private func recordIntervention(
        context: ModelContext,
        trigger: String,
        action: String,
        message: String,
        dose: DailyDose,
        insight: AIInsight,
        sessionId: String?
    ) {
        let intervention = AgentInterventionEvent(
            trigger: trigger,
            action: action,
            message: message,
            dosePercent: dose.dosePercent,
            etaSeconds: insight.etaToLimit,
            burnRatePerHour: insight.burnRatePerHour,
            listeningSessionId: sessionId
        )
        context.insert(intervention)
    }

    private func updateComplianceIfNeeded(
        modelContext: ModelContext,
        samples: [ExposureSample],
        now: Date
    ) async {
        let pendingPredicate = #Predicate<AgentInterventionEvent> { event in
            event.isResolved == false
        }
        let descriptor = FetchDescriptor<AgentInterventionEvent>(predicate: pendingPredicate)
        guard let pending = try? modelContext.fetch(descriptor), !pending.isEmpty else { return }

        for intervention in pending {
            let elapsed = now.timeIntervalSince(intervention.timestamp)
            if elapsed < 60 {
                continue
            }

            let beforeWindowStart = intervention.timestamp.addingTimeInterval(-5 * 60)
            let afterWindowEnd = min(now, intervention.timestamp.addingTimeInterval(5 * 60))

            let beforeSamples = samples.filter {
                $0.endDate >= beforeWindowStart && $0.endDate <= intervention.timestamp
            }
            let afterSamples = samples.filter {
                $0.startDate >= intervention.timestamp && $0.startDate <= afterWindowEnd
            }

            let beforeAverage = averageLevel(from: beforeSamples)
            let afterAverage = averageLevel(from: afterSamples)

            if let firstAfter = afterSamples.first {
                let gap = firstAfter.startDate.timeIntervalSince(intervention.timestamp)
                if gap >= breakDetectionThreshold {
                    recordCompliance(
                        modelContext: modelContext,
                        intervention: intervention,
                        outcome: "stopped_listening",
                        responseSeconds: gap,
                        volumeDeltaDB: nil,
                        stoppedListening: true
                    )
                    continue
                }
            }

            if afterSamples.isEmpty, elapsed >= complianceWindow {
                recordCompliance(
                    modelContext: modelContext,
                    intervention: intervention,
                    outcome: "stopped_listening",
                    responseSeconds: elapsed,
                    volumeDeltaDB: nil,
                    stoppedListening: true
                )
                continue
            }

            if let beforeAverage, let afterAverage {
                let delta = beforeAverage - afterAverage
                if delta >= volumeDropThresholdDB {
                    let responseSeconds = afterSamples.first.map {
                        $0.startDate.timeIntervalSince(intervention.timestamp)
                    } ?? elapsed
                    recordCompliance(
                        modelContext: modelContext,
                        intervention: intervention,
                        outcome: "volume_reduced",
                        responseSeconds: responseSeconds,
                        volumeDeltaDB: delta,
                        stoppedListening: false
                    )
                    continue
                }
            }

            if elapsed >= complianceWindow {
                recordCompliance(
                    modelContext: modelContext,
                    intervention: intervention,
                    outcome: "no_change",
                    responseSeconds: elapsed,
                    volumeDeltaDB: nil,
                    stoppedListening: false
                )
            }
        }
    }

    private func averageLevel(from samples: [ExposureSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { $0 + $1.levelDBASPL }
        return total / Double(samples.count)
    }

    private func recordCompliance(
        modelContext: ModelContext,
        intervention: AgentInterventionEvent,
        outcome: String,
        responseSeconds: Double?,
        volumeDeltaDB: Double?,
        stoppedListening: Bool
    ) {
        // TEMP: log detected user response to interventions
        print("🤖 AI compliance: outcome=\(outcome) responseSeconds=\(responseSeconds?.rounded() ?? 0) volumeDeltaDB=\(volumeDeltaDB?.rounded() ?? 0) stopped=\(stoppedListening)")
        let compliance = AgentComplianceEvent(
            interventionId: intervention.id,
            outcome: outcome,
            responseSeconds: responseSeconds,
            volumeDeltaDB: volumeDeltaDB,
            stoppedListening: stoppedListening
        )
        modelContext.insert(compliance)
        intervention.isResolved = true
        intervention.resolvedAt = Date()
        intervention.complianceOutcome = outcome
    }

    private func updateHealthKitStatusIfNeeded(
        modelContext: ModelContext,
        now: Date
    ) async {
        let descriptor = FetchDescriptor<AgentHealthKitStatus>()
        let status = (try? modelContext.fetch(descriptor).first) ?? {
            let newStatus = AgentHealthKitStatus()
            modelContext.insert(newStatus)
            return newStatus
        }()

        status.authorizationStatus = String(describing: HealthKitService.shared.authorizationStatus)

        if let lastSync = latestHealthKitSyncDate(context: modelContext) {
            status.lastSyncDate = lastSync
        }

        status.lastSyncResult = status.lastSyncResult ?? "unknown"
        _ = now
    }

    private func latestHealthKitSyncDate(context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<SyncState>()
        guard let states = try? context.fetch(descriptor) else { return nil }
        let dates = states.compactMap { $0.lastSyncDate }
        return dates.max()
    }

    private func maybeTriggerHealthKitSync(
        modelContext: ModelContext,
        state: AgentState,
        now: Date
    ) async -> Bool {
        if let lastSync = state.lastHealthKitSyncAt,
           now.timeIntervalSince(lastSync) < syncCooldown {
            return false
        }

        guard let latestSync = latestHealthKitSyncDate(context: modelContext) else {
            return false
        }

        if now.timeIntervalSince(latestSync) < syncCooldown {
            return false
        }

        let start = Date()
        do {
            try await HealthKitSyncService.shared.performIncrementalSync()
            state.lastHealthKitSyncAt = Date()
            updateHealthKitSyncResult(modelContext: modelContext, result: "success", duration: Date().timeIntervalSince(start))
            return true
        } catch {
            state.lastHealthKitSyncAt = Date()
            updateHealthKitSyncResult(modelContext: modelContext, result: "error", duration: Date().timeIntervalSince(start))
            return false
        }
    }

    private func updateHealthKitSyncResult(
        modelContext: ModelContext,
        result: String,
        duration: TimeInterval
    ) {
        let descriptor = FetchDescriptor<AgentHealthKitStatus>()
        let status = (try? modelContext.fetch(descriptor).first) ?? {
            let newStatus = AgentHealthKitStatus()
            modelContext.insert(newStatus)
            return newStatus
        }()
        status.lastSyncDate = Date()
        status.lastSyncDurationSeconds = duration
        status.lastSyncResult = result
    }
}
