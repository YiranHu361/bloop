import Foundation
import SwiftData

/// Agent loop that decides when to notify or suggest breaks based on live listening context.
@MainActor
final class AgenticRecommendationService {
    static let shared = AgenticRecommendationService()

    private let evaluationCooldown: TimeInterval = 60
    private let interventionCooldown: TimeInterval = 10 * 60
    private let complianceWindow: TimeInterval = 10 * 60
    private let sessionGap: TimeInterval = 5 * 60
    private let volumeDropThresholdDB: Double = 3
    static let recentSampleWindowSeconds: TimeInterval = 10 * 60
    private let syncCooldown: TimeInterval = 10 * 60

    private init() {}

    func evaluateIfNeeded(
        modelContext: ModelContext,
        dose: DailyDose?,
        samples: [ExposureSample],
        aiInsight: AIInsight,
        currentLevelDB: Double?,
        doseModel: DoseModel
    ) async {
        guard let dose = dose else { return }

        let now = Date()
        let state = fetchOrCreateAgentState(context: modelContext)
        if let lastEvaluatedAt = state.lastEvaluatedAt,
           now.timeIntervalSince(lastEvaluatedAt) < evaluationCooldown {
            return
        }
        state.lastEvaluatedAt = now

        let settings = fetchUserSettings(context: modelContext)

        if isInQuietHours(settings: settings, now: now), !settings.quietHoursStrictMode {
            try? modelContext.save()
            return
        }

        let isActivelyListening = aiInsight.isActivelyListening
        let isRecent = isRecentSample(samples: samples, now: now)
        let isHeadphoneOutput = AudioRouteMonitor.shared.currentOutputType.isHeadphoneType

        guard isActivelyListening, isRecent, isHeadphoneOutput else {
            await updateComplianceIfNeeded(
                modelContext: modelContext,
                samples: samples,
                now: now
            )
            try? modelContext.save()
            return
        }

        await updateHealthKitStatusIfNeeded(modelContext: modelContext, now: now)

        let sessionDuration = currentSessionDuration(samples: samples)
        let sessionId = sessionIdentifier(from: samples)

        if let lastInterventionAt = state.lastInterventionAt,
           now.timeIntervalSince(lastInterventionAt) < interventionCooldown {
            await updateComplianceIfNeeded(
                modelContext: modelContext,
                samples: samples,
                now: now
            )
            try? modelContext.save()
            return
        }

        if await maybeTriggerHealthKitSync(
            modelContext: modelContext,
            state: state,
            now: now
        ) {
            try? modelContext.save()
        }

        if dose.dosePercent >= Double(settings.dailyExposureLimit) {
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
        } else if let eta = aiInsight.etaToLimit, eta <= 30 * 60 {
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
        } else if settings.breakRemindersEnabled,
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
        } else if settings.instantVolumeAlerts,
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
            let afterWindowEnd = min(now, intervention.timestamp.addingTimeInterval(complianceWindow))

            let beforeSamples = samples.filter {
                $0.endDate >= beforeWindowStart && $0.endDate <= intervention.timestamp
            }
            let afterSamples = samples.filter {
                $0.startDate >= intervention.timestamp && $0.startDate <= afterWindowEnd
            }

            let beforeAverage = averageLevel(from: beforeSamples)
            let afterAverage = averageLevel(from: afterSamples)

            if afterSamples.isEmpty, elapsed > 5 * 60 {
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
                    recordCompliance(
                        modelContext: modelContext,
                        intervention: intervention,
                        outcome: "volume_reduced",
                        responseSeconds: elapsed,
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
