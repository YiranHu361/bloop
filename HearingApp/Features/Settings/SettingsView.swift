import SwiftUI
import SwiftData

/// Enhanced Settings view
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @State private var notify50Percent = true
    @State private var notify75Percent = true
    @State private var notify100Percent = true
    @State private var selectedDoseModel: DoseModel = .niosh
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $notify50Percent) {
                        AlertToggleRow(percent: 50, icon: "bell", color: AppColors.safe)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))

                    Toggle(isOn: $notify75Percent) {
                        AlertToggleRow(percent: 75, icon: "bell.badge", color: AppColors.caution)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))

                    Toggle(isOn: $notify100Percent) {
                        AlertToggleRow(percent: 100, icon: "bell.badge.fill", color: AppColors.danger)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
                } header: {
                    sectionHeader(icon: "bell.badge", title: "Alerts")
                }

                Section {
                    Picker("Calculation Model", selection: $selectedDoseModel) {
                        ForEach(DoseModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    sectionHeader(icon: "function", title: "Dose Calculation")
                } footer: {
                    Text("NIOSH/WHO is recommended for most users.")
                        .font(AppTypography.caption1)
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                } header: {
                    sectionHeader(icon: "externaldrive", title: "Data")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.4.0")
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                } header: {
                    sectionHeader(icon: "info.circle", title: "About")
                }

                #if DEBUG
                Section {
                    Button("Generate Sample Data") {
                        generateSampleData()
                    }
                    Button("Reset Onboarding") {
                        appState.resetOnboarding()
                    }
                } header: {
                    Text("Debug")
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Clear All Data?", isPresented: $showResetConfirmation) {
                Button("Clear Everything", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all your listening history.")
            }
        }
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.primaryFallback)
            Text(title.uppercased())
        }
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: DailyDose.self)
            try modelContext.delete(model: ExposureSample.self)
            try modelContext.delete(model: ExposureEvent.self)
            try modelContext.delete(model: SyncState.self)
            try modelContext.save()
        } catch {
            print("Error clearing data: \(error)")
        }
    }

    private func generateSampleData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for daysAgo in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            let dosePercent = Double.random(in: 20...120)
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
            modelContext.insert(dose)
        }
        try? modelContext.save()
    }
}

struct AlertToggleRow: View {
    let percent: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Notify at \(percent)%")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.label)
            }
        }
    }
}
