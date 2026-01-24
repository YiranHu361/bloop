import SwiftUI
import SwiftData

/// bloop. Settings - Comprehensive Parental Control Center
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    
    @State private var showPrivacyPolicy = false
    @State private var showExportSheet = false
    @State private var showResetConfirmation = false
    @State private var showPINSetup = false
    @State private var showPINEntry = false
    @State private var selectedPreset: SettingsPreset = .standard
    
    var body: some View {
        NavigationStack {
            List {
                // Quick Presets
                presetsSection
                
                // Daily Limits
                dailyLimitsSection
                
                // Alert Thresholds
                alertsSection
                
                // Break Reminders
                breakRemindersSection
                
                // Quiet Hours
                quietHoursSection
                
                // Notifications
                notificationsSection
                
                // PIN Protection
                pinProtectionSection
                
                // Weekly Reports
                weeklyReportsSection
                
                // Exposure Standard
                exposureStandardSection
                
                // Data & Storage
                dataStorageSection
                
                // Privacy
                privacySection
                
                // About
                aboutSection
                
                // Debug (only in debug builds)
                #if DEBUG
                debugSection
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Parent Controls")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicySheet()
            }
            .sheet(isPresented: $showPINSetup) {
                PINSetupSheet(viewModel: viewModel)
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
                Text("This will permanently delete all listening history. This action cannot be undone.")
            }
            .onChange(of: viewModel.dailyExposureLimit) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.notify60Percent) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.notify80Percent) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.notify100Percent) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.breakRemindersEnabled) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.breakIntervalMinutes) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.breakEnforcement) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.quietHoursEnabled) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.quietHoursStart) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.quietHoursEnd) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.notificationStyle) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.liveActivityEnabled) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.instantVolumeAlerts) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.volumeAlertThresholdDB) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.kidFriendlyMessages) { _, _ in viewModel.saveSettings() }
            .onChange(of: viewModel.weeklyReportEnabled) { _, _ in viewModel.saveSettings() }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        Section {
            ForEach(SettingsPreset.allCases) { preset in
                PresetRow(
                    preset: preset,
                    isSelected: selectedPreset == preset
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPreset = preset
                        viewModel.applyPreset(preset)
                    }
                }
            }
        } header: {
            sectionHeader(icon: "sparkles", title: "Quick Setup")
        } footer: {
            Text("Choose a preset to quickly configure all settings, or customize each option below.")
                .font(AppTypography.caption1)
        }
    }
    
    // MARK: - Daily Limits Section
    
    private var dailyLimitsSection: some View {
        Section {
            // Daily exposure limit picker
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Daily Limit", systemImage: "gauge.with.dots.needle.50percent")
                        .font(AppTypography.subheadline)
                    Spacer()
                    Text("\(viewModel.dailyExposureLimit)%")
                        .font(AppTypography.headline)
                        .foregroundColor(limitColor(viewModel.dailyExposureLimit))
                }
                
                Picker("Daily Limit", selection: $viewModel.dailyExposureLimit) {
                    ForEach(SettingsViewModel.dailyLimitOptions, id: \.self) { limit in
                        Text("\(limit)%").tag(limit)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
            
            Toggle(isOn: $viewModel.enforceLimit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strong Warning at Limit")
                        .font(AppTypography.subheadline)
                    Text("Show prominent alert when limit is reached")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            
        } header: {
            sectionHeader(icon: "chart.pie", title: "Daily Exposure Limit")
        } footer: {
            Text("Set how much daily exposure is allowed before strong warnings. 100% = 8 hours at 85 dB.")
                .font(AppTypography.caption1)
        }
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        Section {
            AlertToggleRow(
                percent: 60,
                icon: "bell",
                color: AppColors.safe,
                subtitle: "Heads-up notification",
                isEnabled: $viewModel.notify60Percent
            )
            
            AlertToggleRow(
                percent: 80,
                icon: "bell.badge",
                color: AppColors.caution,
                subtitle: "Warning notification",
                isEnabled: $viewModel.notify80Percent
            )
            
            AlertToggleRow(
                percent: 100,
                icon: "bell.badge.fill",
                color: AppColors.danger,
                subtitle: "Strong alert + break suggestion",
                isEnabled: $viewModel.notify100Percent
            )
            
            // Instant volume alerts
            Toggle(isOn: $viewModel.instantVolumeAlerts) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(AppColors.danger)
                        Text("Instant Loud Volume Alert")
                            .font(AppTypography.subheadline)
                    }
                    Text("Alert immediately when volume exceeds \(viewModel.volumeAlertThresholdDB) dB")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            
            if viewModel.instantVolumeAlerts {
                Picker("Volume Threshold", selection: $viewModel.volumeAlertThresholdDB) {
                    ForEach(SettingsViewModel.volumeThresholdOptions, id: \.self) { db in
                        Text("\(db) dB").tag(db)
                    }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            sectionHeader(icon: "bell.badge", title: "Alert Thresholds")
        } footer: {
            Text("bloop. alerts when listening gets too loud, but never abruptly cuts sound.")
                .font(AppTypography.caption1)
        }
    }
    
    // MARK: - Break Reminders Section
    
    private var breakRemindersSection: some View {
        Section {
            Toggle(isOn: $viewModel.breakRemindersEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(AppColors.primaryFallback)
                        Text("Break Reminders")
                            .font(AppTypography.subheadline)
                    }
                    Text("Remind to take breaks during long listening sessions")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            
            if viewModel.breakRemindersEnabled {
                Picker("Remind Every", selection: $viewModel.breakIntervalMinutes) {
                    ForEach(SettingsViewModel.breakIntervalOptions, id: \.self) { mins in
                        Text("\(mins) min").tag(mins)
                    }
                }
                
                Picker("Break Duration", selection: $viewModel.breakDurationMinutes) {
                    ForEach(SettingsViewModel.breakDurationOptions, id: \.self) { mins in
                        Text("\(mins) min").tag(mins)
                    }
                }
                
                // Break enforcement level
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder Style")
                        .font(AppTypography.subheadline)
                    
                    Picker("Style", selection: $viewModel.breakEnforcement) {
                        ForEach(BreakEnforcementLevel.allCases) { level in
                            Label(level.displayName, systemImage: level.icon).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(viewModel.breakEnforcement.description)
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        } header: {
            sectionHeader(icon: "cup.and.saucer", title: "Break Reminders")
        } footer: {
            Text("Regular breaks help protect hearing. The 60/60 rule: listen at 60% volume for max 60 minutes.")
                .font(AppTypography.caption1)
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        Section {
            Toggle(isOn: $viewModel.quietHoursEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                        Text("Quiet Hours")
                            .font(AppTypography.subheadline)
                    }
                    Text("Set times when headphone use should be limited")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            
            if viewModel.quietHoursEnabled {
                DatePicker(
                    "Start Time",
                    selection: $viewModel.quietHoursStart,
                    displayedComponents: .hourAndMinute
                )
                
                DatePicker(
                    "End Time",
                    selection: $viewModel.quietHoursEnd,
                    displayedComponents: .hourAndMinute
                )
                
                Toggle(isOn: $viewModel.quietHoursStrictMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Strict Mode")
                            .font(AppTypography.subheadline)
                        Text("Send alerts if headphones are used during quiet hours")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            }
        } header: {
            sectionHeader(icon: "moon.stars", title: "Quiet Hours")
        } footer: {
            Text("Good sleep is important! Set quiet hours for bedtime when headphone use isn't recommended.")
                .font(AppTypography.caption1)
        }
    }
    
    // MARK: - Notifications Section
    
    private var notificationsSection: some View {
        Section {
            // Notification style
            VStack(alignment: .leading, spacing: 8) {
                Text("Notification Style")
                    .font(AppTypography.subheadline)
                
                Picker("Style", selection: $viewModel.notificationStyle) {
                    ForEach(NotificationStyle.allCases) { style in
                        Label(style.displayName, systemImage: style.icon).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                
                Text(viewModel.notificationStyle.description)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
            .padding(.vertical, 4)
            
            Toggle(isOn: $viewModel.liveActivityEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "livephoto")
                            .foregroundColor(AppColors.primaryFallback)
                        Text("Live Activity")
                            .font(AppTypography.subheadline)
                    }
                    Text("Show real-time exposure on Lock Screen & Dynamic Island")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            
            Toggle(isOn: $viewModel.kidFriendlyMessages) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "face.smiling")
                            .foregroundColor(AppColors.safe)
                        Text("Kid-Friendly Messages")
                            .font(AppTypography.subheadline)
                    }
                    Text("Use playful, encouraging language in notifications")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            
        } header: {
            sectionHeader(icon: "app.badge", title: "Notifications")
        } footer: {
            Text("Prominent notifications help kids notice alerts. Live Activity shows exposure on the Lock Screen.")
                .font(AppTypography.caption1)
        }
    }
    
    // MARK: - PIN Protection Section
    
    private var pinProtectionSection: some View {
        Section {
            if viewModel.pinProtectionEnabled {
                HStack {
                    Label("PIN Protection", systemImage: "lock.fill")
                        .font(AppTypography.subheadline)
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(AppColors.safe)
                }
                
                Button(action: { showPINSetup = true }) {
                    Label("Change PIN", systemImage: "key")
                }
                
                Button(role: .destructive, action: { viewModel.removePIN() }) {
                    Label("Remove PIN", systemImage: "lock.open")
                }
            } else {
                Button(action: { showPINSetup = true }) {
                    HStack {
                        Label("Set Up PIN", systemImage: "lock.shield")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
            }
        } header: {
            sectionHeader(icon: "lock.shield", title: "PIN Protection")
        } footer: {
            Text("Prevent kids from changing settings. You'll need the PIN to access Parent Controls.")
                .font(AppTypography.caption1)
        }
    }
    
    // MARK: - Weekly Reports Section
    
    private var weeklyReportsSection: some View {
        Section {
            Toggle(isOn: $viewModel.weeklyReportEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundColor(AppColors.primaryFallback)
                        Text("Weekly Summary")
                            .font(AppTypography.subheadline)
                    }
                    Text("Get a weekly report of listening habits")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
            
            if viewModel.weeklyReportEnabled {
                Picker("Report Day", selection: $viewModel.weeklyReportDay) {
                    ForEach(SettingsViewModel.weekdayOptions, id: \.0) { day, name in
                        Text(name).tag(day)
                    }
                }
            }
        } header: {
            sectionHeader(icon: "calendar", title: "Weekly Reports")
        }
    }
    
    // MARK: - Exposure Standard Section
    
    private var exposureStandardSection: some View {
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
    }
    
    // MARK: - Data & Storage Section
    
    private var dataStorageSection: some View {
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
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
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
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
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
    }
    
    // MARK: - Debug Section
    
    #if DEBUG
    private var debugSection: some View {
        Section {
            Button("Generate Sample Data") {
                Task {
                    await viewModel.generateSampleData(context: modelContext)
                }
            }
            
            Button("Reset Onboarding") {
                appState.resetOnboarding()
            }
            
            Button("Test Live Activity") {
                Task {
                    await BloopLiveActivity.shared.startExposureTracking(
                        currentPercent: 75,
                        currentDB: 82,
                        status: .moderate
                    )
                }
            }
            
            Button("End Live Activity") {
                Task {
                    await BloopLiveActivity.shared.endActivity()
                }
            }
        } header: {
            Text("Debug")
        }
    }
    #endif
    
    // MARK: - Helpers
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.primaryFallback)
            
            Text(title.uppercased())
        }
    }
    
    private func limitColor(_ limit: Int) -> Color {
        switch limit {
        case ..<90: return AppColors.safe
        case 90..<110: return AppColors.caution
        default: return AppColors.danger
        }
    }
}

// MARK: - Preset Row

struct PresetRow: View {
    let preset: SettingsPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(presetColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: presetIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(presetColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.displayName)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.label)
                    
                    Text(preset.description)
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.primaryFallback)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var presetColor: Color {
        switch preset {
        case .kidSafe: return AppColors.safe
        case .standard: return AppColors.primaryFallback
        case .custom: return AppColors.caution
        }
    }
    
    private var presetIcon: String {
        switch preset {
        case .kidSafe: return "shield.checkered"
        case .standard: return "checkmark.shield"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Alert Toggle Row

struct AlertToggleRow: View {
    let percent: Int
    let icon: String
    let color: Color
    var subtitle: String? = nil
    @Binding var isEnabled: Bool
    
    var body: some View {
        Toggle(isOn: $isEnabled) {
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
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryFallback))
    }
}

// MARK: - PIN Setup Sheet

struct PINSetupSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var pin: String = ""
    @State private var confirmPIN: String = ""
    @State private var step: Int = 1
    @State private var showError: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                Image(systemName: step == 1 ? "lock.shield" : "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.primaryFallback)
                
                Text(step == 1 ? "Create a PIN" : "Confirm your PIN")
                    .font(AppTypography.title2)
                
                Text(step == 1 ? "This PIN will protect your settings" : "Enter the same PIN again")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.secondaryLabel)
                
                // PIN entry
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(pinFilled(index) ? AppColors.primaryFallback : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                
                if showError {
                    Text("PINs don't match. Try again.")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.danger)
                }
                
                // Number pad
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(1...9, id: \.self) { num in
                        NumberButton(number: "\(num)") { enterDigit("\(num)") }
                    }
                    
                    Spacer()
                    
                    NumberButton(number: "0") { enterDigit("0") }
                    
                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.label)
                            .frame(width: 70, height: 70)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("Set PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func pinFilled(_ index: Int) -> Bool {
        let currentPIN = step == 1 ? pin : confirmPIN
        return index < currentPIN.count
    }
    
    private func enterDigit(_ digit: String) {
        showError = false
        
        if step == 1 {
            if pin.count < 4 {
                pin += digit
                if pin.count == 4 {
                    step = 2
                }
            }
        } else {
            if confirmPIN.count < 4 {
                confirmPIN += digit
                if confirmPIN.count == 4 {
                    if pin == confirmPIN {
                        viewModel.setPIN(pin)
                        dismiss()
                    } else {
                        showError = true
                        confirmPIN = ""
                    }
                }
            }
        }
    }
    
    private func deleteDigit() {
        if step == 1 && !pin.isEmpty {
            pin.removeLast()
        } else if step == 2 && !confirmPIN.isEmpty {
            confirmPIN.removeLast()
        } else if step == 2 && confirmPIN.isEmpty {
            step = 1
            pin = ""
        }
    }
}

struct NumberButton: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(AppColors.label)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                )
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
                acknowledgementRow(title: "Apple HealthKit", detail: "Headphone audio exposure data")
                acknowledgementRow(title: "SwiftUI", detail: "User interface framework")
                acknowledgementRow(title: "SwiftData", detail: "Local data persistence")
            }
            
            Section("Research") {
                acknowledgementRow(title: "WHO", detail: "Safe listening guidelines")
                acknowledgementRow(title: "NIOSH", detail: "Noise exposure criteria")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func acknowledgementRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.subheadline)
            Text(detail)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Monitoring Mode (kept for compatibility)

enum MonitoringMode: String, CaseIterable, Identifiable {
    case standard = "standard"
    case privacy = "privacy"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .privacy: return "Privacy Mode"
        }
    }
    
    var icon: String {
        switch self {
        case .standard: return "waveform.path.ecg"
        case .privacy: return "eye.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .standard: return AppColors.primaryFallback
        case .privacy: return AppColors.safe
        }
    }
    
    var badge: String? {
        return nil
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .modelContainer(for: [UserSettings.self])
}
