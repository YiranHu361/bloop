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
                // Monitoring Mode Section
                Section {
                    MonitoringModeSelector(selectedMode: $viewModel.monitoringMode)
                } header: {
                    sectionHeader(icon: "slider.horizontal.3", title: "Display Mode")
                } footer: {
                    Text("Both modes provide the same hearing protection. Privacy Mode just shows less detail on screen.")
                        .font(AppTypography.caption1)
                }
                
                // Alerts & Nudges Section (Parent Controls)
                Section {
                    Toggle(isOn: $viewModel.notify60Percent) {
                        AlertToggleRow(
                            percent: 60,
                            icon: "bell",
                            color: AppColors.safe,
                            subtitle: "Heads-up notification"
                        )
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
                    
                    Toggle(isOn: $viewModel.notify80Percent) {
                        AlertToggleRow(
                            percent: 80,
                            icon: "bell.badge",
                            color: AppColors.caution,
                            subtitle: "Warning notification"
                        )
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
                    
                    Toggle(isOn: $viewModel.notify100Percent) {
                        AlertToggleRow(
                            percent: 100,
                            icon: "bell.badge.fill",
                            color: AppColors.danger,
                            subtitle: "Strong alert + break suggestion"
                        )
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
                    
                    // Break suggestions toggle
                    Toggle(isOn: $viewModel.breakSuggestionsEnabled) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primaryFallback.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.primaryFallback)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Break Reminders")
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.label)
                                
                                Text("Gentle suggestions to take a break")
                                    .font(AppTypography.caption1)
                                    .foregroundColor(AppColors.secondaryLabel)
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
                } header: {
                    sectionHeader(icon: "bell.badge", title: "Alerts & Nudges")
                } footer: {
                    Text("bloop. alerts you when listening gets too loud, but never abruptly cuts sound.")
                        .font(AppTypography.caption1)
                }
                
                // Exposure Standard Section
                Section {
                    Picker("Exposure Standard", selection: $viewModel.doseModel) {
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
                    sectionHeader(icon: "ear.badge.waveform", title: "Exposure Standard")
                } footer: {
                    Text("WHO/NIOSH is recommended. 85 dB for 8 hours = 100% daily exposure.")
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

// MARK: - Monitoring Mode Selector

struct MonitoringModeSelector: View {
    @Binding var selectedMode: MonitoringMode
    
    var body: some View {
        ForEach(MonitoringMode.allCases, id: \.self) { mode in
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedMode = mode
                }
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(mode.color.opacity(0.12))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: mode.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(mode.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(mode.displayName)
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.label)
                            
                            if let badge = mode.badge {
                                Text(badge)
                                    .font(AppTypography.caption2)
                                    .foregroundColor(AppColors.primaryFallback)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.primaryFallback.opacity(0.12))
                                    )
                            }
                        }
                        
                        Text(mode.detailedDescription)
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    if selectedMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.primaryFallback)
                    } else {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
}

enum MonitoringMode: String, CaseIterable {
    case standard = "standard"
    case privacy = "privacy"
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .privacy: return "Privacy Mode"
        }
    }
    
    var description: String {
        switch self {
        case .standard: return "Full hearing protection with detailed insights"
        case .privacy: return "Same protection, minimal data display"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .standard: return "See your listening patterns, volume levels, and personalized recommendations."
        case .privacy: return "App still protects your hearing but shows less detail. Good if you prefer a simpler view."
        }
    }
    
    var icon: String {
        switch self {
        case .standard: return "waveform.path.ecg"
        case .privacy: return "lock.shield"
        }
    }
    
    var color: Color {
        switch self {
        case .standard: return AppColors.primaryFallback
        case .privacy: return AppColors.safe
        }
    }
    
    var badge: String? {
        switch self {
        case .standard: return "Recommended"
        case .privacy: return nil
        }
    }
}

// MARK: - Alert Toggle Row

struct AlertToggleRow: View {
    let percent: Int
    let icon: String
    let color: Color
    var subtitle: String? = nil
    
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
                Text("Alert at \(percent)%")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.label)
                
                Text(subtitle ?? alertDescription(for: percent))
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
    }
    
    private func alertDescription(for percent: Int) -> String {
        switch percent {
        case 60: return "Getting loud"
        case 80: return "Approaching daily limit"
        case 100: return "Daily limit reached"
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
                Text("All data stays on this device")
            }
            
            HStack(spacing: 4) {
                Image(systemName: "mic.slash.fill")
                    .foregroundColor(AppColors.safe)
                Text("No microphone access")
            }
            
            HStack(spacing: 4) {
                Image(systemName: "phone.down.fill")
                    .foregroundColor(AppColors.safe)
                Text("Phone calls stay completely private")
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
                        Text("Privacy is Our Promise")
                            .font(AppTypography.title2)
                        
                        Text("bloop. measures loudness, not listening. Here's what that means:")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    
                    privacyItem(
                        icon: "mic.slash.fill",
                        title: "No Microphone Access",
                        description: "bloop. never uses the microphone. We can't hear conversations, music, or any audio."
                    )
                    
                    privacyItem(
                        icon: "phone.down.fill",
                        title: "Phone Calls Stay Private",
                        description: "iOS doesn't allow apps to access call audio. Phone calls are completely private."
                    )
                    
                    privacyItem(
                        icon: "heart.fill",
                        title: "HealthKit Volume Data Only",
                        description: "We read headphone volume levels from HealthKit — just a number, not what your child listens to."
                    )
                    
                    privacyItem(
                        icon: "iphone",
                        title: "All Data Stays On-Device",
                        description: "Nothing is sent to servers. You control all data and can delete it anytime."
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
