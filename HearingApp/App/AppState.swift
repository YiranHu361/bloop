import SwiftUI
import Combine

/// Global app state for cross-cutting concerns
@MainActor
final class AppState: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("selectedDoseModel") private var selectedDoseModelRaw: String = DoseModel.niosh.rawValue

    @Published var healthKitAuthorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    @Published var currentDailyDose: Double = 0.0
    @Published var isLoading: Bool = false

    var selectedDoseModel: DoseModel {
        get { DoseModel(rawValue: selectedDoseModelRaw) ?? .niosh }
        set { selectedDoseModelRaw = newValue.rawValue }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}

enum HealthKitAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable
}
