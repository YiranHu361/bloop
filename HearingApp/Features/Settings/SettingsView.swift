import SwiftUI
import SwiftData

/// Enhanced Settings view with privacy tiers and organized sections
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    
    @State private var showPrivacyPolicy = false
    @State private var showExportSheet = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Alerts & Notifications Section
                Section {
                    Toggle(isOn: $viewModel.notify60Percent) {
                        AlertToggleRow(
                            percent: 60,
                            icon: "bell",
                            color: AppColors.safe
                        )
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))

                    Toggle(isOn: $viewModel.notify80Percent) {
                        AlertToggleRow(
                            percent: 80,
                            icon: "bell.badge",
                            color: AppColors.caution
                        )
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))

                    Toggle(isOn: $viewModel.notify100Percent) {
                        AlertToggleRow(
                            percent: 100,
                            icon: "bell.badge.fill",
                            color: AppColors.danger
                        )
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
                } header: {
                    sectionHeader(icon: "bell.badge", title: "Alerts & Notifications")
                }
                
                // Dose Model Section
                Section {
                    Picker("Calculation Model", selection: $viewModel.doseModel) {
                        ForEach(DoseModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    NavigationLink {
                        AccuracyInfoView()
                    } label: {
                        Label("About Accuracy", systemImage: "info.circle")
                    }
                } header: {
                    sectionHeader(icon: "function", title: "Dose Calculation")
                } footer: {
                    Text("NIOSH/WHO is recommended for most users. OSHA is the US workplace standard.")
                        .font(AppTypography.caption1)
                }
                
                // Data & Storage Section
                Section {
                    Picker("Keep History", selection: $viewModel.historyDuration) {
                        Text("7 Days").tag(7)
                        Text("30 Days").tag(30)
                        Text("90 Days").tag(90)
                        Text("Forever").tag(0)
                    }
                    .pickerStyle(.navigationLink)
                    
                    Button(action: { showExportSheet = true }) {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: { showResetConfirmation = true }) {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                } header: {
                    sectionHeader(icon: "externaldrive", title: "Data & Storage")
                }
                
                // Privacy Section
                Section {
                    NavigationLink {
                        PrivacyDetailView()
                    } label: {
                        Label("Privacy Details", systemImage: "hand.raised.fill")
                    }
                    
                    Button(action: { showPrivacyPolicy = true }) {
                        Label("Privacy Policy", systemImage: "doc.text")
                    }
                } header: {
                    sectionHeader(icon: "lock.shield", title: "Privacy")
                } footer: {
                    PrivacyFooter()
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    
                    NavigationLink {
                        AcknowledgementsView()
                    } label: {
                        Label("Acknowledgements", systemImage: "heart")
                    }
                } header: {
                    sectionHeader(icon: "info.circle", title: "About")
                }
                
                // Debug Section (only in debug builds)
                #if DEBUG
                Section {
                    Button("Generate Sample Data") {
                        Task {
                            await viewModel.generateSampleData(context: modelContext)
                        }
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
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicySheet()
            }
            .confirmationDialog(
                "Clear All Data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) {
                    Task {
                        await viewModel.clearAllData(context: modelContext)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your listening history. This action cannot be undone.")
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
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
}

// MARK: - Alert Toggle Row

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
                
                Text(alertDescription(for: percent))
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
    }
    
    private func alertDescription(for percent: Int) -> String {
        switch percent {
        case 50: return "Halfway to daily limit"
        case 75: return "Approaching limit"
        case 100: return "Limit reached"
        default: return ""
        }
    }
}

// MARK: - Privacy Footer

struct PrivacyFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(AppColors.safe)
                Text("Your data stays on this device")
            }
            
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.safe)
                Text("AI insights use Gemini (no personal data)")
            }
            
            HStack(spacing: 4) {
                Image(systemName: "phone.down.fill")
                    .foregroundColor(AppColors.safe)
                Text("Phone calls cannot be accessed")
            }
            
            HStack(spacing: 4) {
                Image(systemName: "network.slash")
                    .foregroundColor(AppColors.safe)
                Text("No data sent to servers")
            }
        }
        .font(AppTypography.caption1)
        .foregroundColor(AppColors.secondaryLabel)
        .padding(.top, 8)
    }
}

// MARK: - Privacy Policy Sheet

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Privacy Matters")
                            .font(AppTypography.title2)
                        
                        Text("SafeSound is designed with your privacy as a top priority. Here's what you need to know:")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    
                    privacyItem(
                        icon: "sparkles",
                        title: "AI-Powered Insights",
                        description: "Personalized hearing advice is powered by Gemini AI. Only anonymized dose data is sent, never personal information."
                    )
                    
                    privacyItem(
                        icon: "phone.down.fill",
                        title: "Phone Calls Stay Private",
                        description: "iOS does not allow apps to access phone call audio. Your calls are completely private."
                    )
                    
                    privacyItem(
                        icon: "heart.fill",
                        title: "HealthKit Volume Data",
                        description: "We read headphone volume levels from HealthKit. This is just a number, not what you're listening to."
                    )
                    
                    privacyItem(
                        icon: "iphone",
                        title: "On-Device Processing",
                        description: "All data stays on your phone. Nothing is sent to servers or shared with anyone."
                    )
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func privacyItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.safe.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.safe)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
                
                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
    }
}

// MARK: - Acknowledgements View

struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                Text("SafeSound uses scientifically-backed guidelines to help protect your hearing.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.secondaryLabel)
            }
            
            Section("Standards & Guidelines") {
                acknowledgementRow(title: "WHO Safe Listening Guidelines", detail: "World Health Organization")
                acknowledgementRow(title: "NIOSH Noise Exposure Standards", detail: "National Institute for Occupational Safety and Health")
            }
            
            Section("Apple Technologies") {
                acknowledgementRow(title: "HealthKit", detail: "Headphone audio exposure data")
                acknowledgementRow(title: "SwiftUI", detail: "User interface framework")
                acknowledgementRow(title: "SwiftData", detail: "Local data persistence")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func acknowledgementRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.label)
            
            Text(detail)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .modelContainer(for: [UserSettings.self])
}
