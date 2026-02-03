import Foundation
import SwiftUI
import SwiftData
import Combine

/// Notification posted when a new HealthKit exposure sample arrives during live streaming
extension Notification.Name {
    static let exposureSampleArrived = Notification.Name("exposureSampleArrived")
}

/// Payload for exposure sample arrival notification
struct ExposureSamplePayload {
    let timestamp: Date
    let levelDBASPL: Double
    let durationSeconds: TimeInterval
}

/// Coordinates listening session detection and Live Activity updates.
/// 
/// Session lifecycle:
/// - **Start**: headphones connected + new HealthKit sample arrives
/// - **Update**: each new sample recalculates daily dose and updates Live Activity
/// - **End**: headphones disconnect OR no samples for inactivityTimeout
@MainActor
final class LiveSessionCoordinator: ObservableObject {
    static let shared = LiveSessionCoordinator()
    
    // MARK: - Published State
    
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var lastSampleTime: Date?
    @Published private(set) var currentDosePercent: Double = 0
    @Published private(set) var dailyLimitPercent: Int = 100
    
    var remainingPercent: Double {
        max(0, Double(dailyLimitPercent) - currentDosePercent)
    }
    
    var usedPercent: Double {
        min(currentDosePercent, Double(dailyLimitPercent))
    }
    
    // MARK: - Configuration
    
    /// How long without samples before ending session (default: 5 minutes)
    var inactivityTimeout: TimeInterval = 5 * 60
    
    // MARK: - Private
    
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private var inactivityTimer: Timer?
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Setup
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Load user settings for daily limit
        loadUserSettings()
    }
    
    private func setupObservers() {
        // Observe headphone connection changes
        AudioRouteMonitor.shared.$isHeadphonesConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                Task { @MainActor [weak self] in
                    self?.handleHeadphoneConnectionChange(isConnected: isConnected)
                }
            }
            .store(in: &cancellables)
        
        // Observe new exposure sample arrivals (posted by HealthKitSyncService)
        NotificationCenter.default.publisher(for: .exposureSampleArrived)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let payload = notification.object as? ExposureSamplePayload else { return }
                    await self?.handleNewSample(payload: payload)
                }
            }
            .store(in: &cancellables)
        
        // Also listen to general HealthKit data updates as fallback
        NotificationCenter.default.publisher(for: .healthKitDataUpdated)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    // Only process if session is active
                    if self?.isSessionActive == true {
                        await self?.refreshDoseAndUpdateActivity()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Headphone Connection Handling
    
    private func handleHeadphoneConnectionChange(isConnected: Bool) {
        if !isConnected && isSessionActive {
            // Headphones disconnected - end session
            endSession(reason: .headphonesDisconnected)
        }
        // Note: We don't start session on connect alone - we wait for HealthKit samples
    }
    
    // MARK: - Sample Handling
    
    private func handleNewSample(payload: ExposureSamplePayload) async {
        // Only process if headphones are connected
        guard AudioRouteMonitor.shared.isHeadphonesConnected else { return }
        
        // Check if Live Activity is enabled in settings
        guard await isLiveActivityEnabled() else { return }
        
        lastSampleTime = payload.timestamp
        
        if !isSessionActive {
            // Start new session
            await startSession()
        } else {
            // Update existing session
            await refreshDoseAndUpdateActivity()
        }
        
        // Reset inactivity timer
        resetInactivityTimer()
    }
    
    // MARK: - Session Lifecycle
    
    private func startSession() async {
        guard !isSessionActive else { return }
        
        isSessionActive = true
        sessionStartTime = Date()
        
        // Load latest dose data
        await refreshDose()
        
        // Start Live Activity with daily limit
        let status = ExposureStatus.from(dosePercent: currentDosePercent)
        await BloopLiveActivity.shared.startExposureTracking(
            currentPercent: Int(currentDosePercent),
            currentDB: 0, // Will be updated with actual data
            status: status,
            dailyLimitPercent: dailyLimitPercent
        )
        
        // Start inactivity timer
        resetInactivityTimer()
        
        // Session started
    }
    
    private func refreshDoseAndUpdateActivity() async {
        await refreshDose()
        await updateLiveActivityWithBudget()
    }
    
    private func refreshDose() async {
        guard let context = modelContext else { return }
        
        do {
            // Fetch today's dose
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let components = calendar.dateComponents([.year, .month, .day], from: today)
            
            guard let year = components.year,
                  let month = components.month,
                  let day = components.day else { return }
            
            let predicate = #Predicate<DailyDose> { dose in
                dose.year == year &&
                dose.month == month &&
                dose.day == day
            }
            
            let descriptor = FetchDescriptor<DailyDose>(predicate: predicate)
            let doses = try context.fetch(descriptor)
            
            if let todayDose = doses.first {
                currentDosePercent = todayDose.dosePercent
            } else {
                currentDosePercent = 0
            }
            
            // Also refresh daily limit from settings
            loadUserSettings()
            
        } catch {
            AppLogger.logError(error, context: "refreshDose", logger: AppLogger.notifications)
        }
    }
    
    private func updateLiveActivityWithBudget() async {
        guard isSessionActive else { return }
        
        let status = ExposureStatus.from(dosePercent: currentDosePercent)
        
        // Calculate remaining minutes at typical listening level (80 dB)
        let calculator = DoseCalculator(model: .niosh)
        let remainingSeconds = calculator.remainingSafeTime(
            currentDosePercent: currentDosePercent,
            at: 80.0 // Assume moderate listening level
        )
        let remainingMinutes = Int(remainingSeconds / 60)
        
        await BloopLiveActivity.shared.updateExposure(
            currentPercent: Int(currentDosePercent),
            currentDB: 0,
            status: status,
            dailyLimitPercent: dailyLimitPercent,
            remainingMinutes: remainingMinutes > 0 ? remainingMinutes : nil
        )
    }
    
    enum SessionEndReason {
        case headphonesDisconnected
        case inactivityTimeout
        case manual
    }
    
    func endSession(reason: SessionEndReason) {
        guard isSessionActive else { return }
        
        isSessionActive = false
        stopInactivityTimer()
        
        // End Live Activity
        Task {
            await BloopLiveActivity.shared.endActivity()
        }
        
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let durationMinutes = Int(duration / 60)
        
        // Session ended
        
        sessionStartTime = nil
        lastSampleTime = nil
    }
    
    // MARK: - Inactivity Timer
    
    private func resetInactivityTimer() {
        stopInactivityTimer()
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleInactivityTimeout()
            }
        }
    }
    
    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    private func handleInactivityTimeout() {
        guard isSessionActive else { return }
        
        // Check if we've really been inactive (no recent samples)
        if let lastSample = lastSampleTime,
           Date().timeIntervalSince(lastSample) >= inactivityTimeout {
            endSession(reason: .inactivityTimeout)
        } else {
            // Reset timer if we got a sample recently
            resetInactivityTimer()
        }
    }
    
    // MARK: - Settings
    
    private func loadUserSettings() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(descriptor)
            
            if let userSettings = settings.first {
                dailyLimitPercent = userSettings.dailyExposureLimit
            } else {
                dailyLimitPercent = 100 // Default
            }
        } catch {
            dailyLimitPercent = 100
        }
    }
    
    private func isLiveActivityEnabled() async -> Bool {
        guard let context = modelContext else { return true }
        
        do {
            let descriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(descriptor)
            return settings.first?.liveActivityEnabled ?? true
        } catch {
            return true
        }
    }
    
    // MARK: - Manual Controls
    
    /// Manually start a session (e.g., for testing or user-initiated)
    func manualStart() async {
        guard !isSessionActive else { return }
        await startSession()
    }
    
    /// Manually end a session
    func manualEnd() {
        endSession(reason: .manual)
    }
    
    /// Force refresh dose data and Live Activity
    func forceRefresh() async {
        await refreshDoseAndUpdateActivity()
    }
}

// MARK: - Session Duration Formatting

extension LiveSessionCoordinator {
    var sessionDurationFormatted: String {
        guard let start = sessionStartTime else { return "—" }
        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var remainingBudgetFormatted: String {
        let remaining = remainingPercent
        if remaining <= 0 {
            return "Limit reached"
        }
        return "\(Int(remaining))% left today"
    }
}
