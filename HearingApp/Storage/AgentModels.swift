import Foundation
import SwiftData

/// Persistent state for the agentic recommendations loop.
@Model
final class AgentState {
    @Attribute(.unique) var id: String
    var lastEvaluatedAt: Date?
    var lastInterventionAt: Date?
    var lastBreakReminderAt: Date?
    var lastDosePercent: Double
    var lastBurnRatePerHour: Double?
    var lastEtaSeconds: Double?
    var lastHealthKitSyncAt: Date?
    var lastHealthKitAuthStatus: String?

    init(
        id: String = "agent_state",
        lastEvaluatedAt: Date? = nil,
        lastInterventionAt: Date? = nil,
        lastBreakReminderAt: Date? = nil,
        lastDosePercent: Double = 0,
        lastBurnRatePerHour: Double? = nil,
        lastEtaSeconds: Double? = nil,
        lastHealthKitSyncAt: Date? = nil,
        lastHealthKitAuthStatus: String? = nil
    ) {
        self.id = id
        self.lastEvaluatedAt = lastEvaluatedAt
        self.lastInterventionAt = lastInterventionAt
        self.lastBreakReminderAt = lastBreakReminderAt
        self.lastDosePercent = lastDosePercent
        self.lastBurnRatePerHour = lastBurnRatePerHour
        self.lastEtaSeconds = lastEtaSeconds
        self.lastHealthKitSyncAt = lastHealthKitSyncAt
        self.lastHealthKitAuthStatus = lastHealthKitAuthStatus
    }
}

/// Records every action the agent takes.
@Model
final class AgentInterventionEvent {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var trigger: String
    var action: String
    var message: String?
    var dosePercent: Double
    var etaSeconds: Double?
    var burnRatePerHour: Double?
    var listeningSessionId: String?
    var isResolved: Bool
    var resolvedAt: Date?
    var complianceOutcome: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        trigger: String,
        action: String,
        message: String? = nil,
        dosePercent: Double,
        etaSeconds: Double? = nil,
        burnRatePerHour: Double? = nil,
        listeningSessionId: String? = nil,
        isResolved: Bool = false,
        resolvedAt: Date? = nil,
        complianceOutcome: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.trigger = trigger
        self.action = action
        self.message = message
        self.dosePercent = dosePercent
        self.etaSeconds = etaSeconds
        self.burnRatePerHour = burnRatePerHour
        self.listeningSessionId = listeningSessionId
        self.isResolved = isResolved
        self.resolvedAt = resolvedAt
        self.complianceOutcome = complianceOutcome
    }
}

/// Tracks whether interventions led to reduced listening or volume.
@Model
final class AgentComplianceEvent {
    @Attribute(.unique) var id: UUID
    var interventionId: UUID
    var timestamp: Date
    var outcome: String
    var responseSeconds: Double?
    var volumeDeltaDB: Double?
    var stoppedListening: Bool

    init(
        id: UUID = UUID(),
        interventionId: UUID,
        timestamp: Date = Date(),
        outcome: String,
        responseSeconds: Double? = nil,
        volumeDeltaDB: Double? = nil,
        stoppedListening: Bool = false
    ) {
        self.id = id
        self.interventionId = interventionId
        self.timestamp = timestamp
        self.outcome = outcome
        self.responseSeconds = responseSeconds
        self.volumeDeltaDB = volumeDeltaDB
        self.stoppedListening = stoppedListening
    }
}

/// Records HealthKit auth and sync status for the agent.
@Model
final class AgentHealthKitStatus {
    @Attribute(.unique) var id: String
    var authorizationStatus: String
    var lastSyncDate: Date?
    var lastSyncDurationSeconds: Double?
    var lastSyncResult: String?

    init(
        id: String = "healthkit_status",
        authorizationStatus: String = "unknown",
        lastSyncDate: Date? = nil,
        lastSyncDurationSeconds: Double? = nil,
        lastSyncResult: String? = nil
    ) {
        self.id = id
        self.authorizationStatus = authorizationStatus
        self.lastSyncDate = lastSyncDate
        self.lastSyncDurationSeconds = lastSyncDurationSeconds
        self.lastSyncResult = lastSyncResult
    }
}
