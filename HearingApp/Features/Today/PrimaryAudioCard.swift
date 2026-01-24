import SwiftUI

/// Primary dashboard card that toggles between Live Spectrum and Exposure Zones views.
/// Provides a unified top-level visualization with consistent glass styling.
struct PrimaryAudioCard: View {
    enum Mode: String, CaseIterable, Identifiable {
        case spectrum = "Spectrum"
        case zones = "Zones"
        
        var id: String { rawValue }
    }
    
    @ObservedObject var spectrumService: AudioSpectrumService
    let bands: [ExposureBand]
    let currentLevelDB: Double?
    let isMonitoring: Bool
    
    @State private var mode: Mode = .spectrum
    @Environment(\.colorScheme) private var colorScheme
    
    private let barCount = 32
    private let barSpacing: CGFloat = 3
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with centered toggle
            headerWithToggle
            
            // Content based on mode
            switch mode {
            case .spectrum:
                spectrumContent
            case .zones:
                zonesContent
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
        .shadow(color: AppColors.cardShadow, radius: 12, x: 0, y: 6)
        .onAppear {
            spectrumService.checkPermission()
            if mode == .spectrum && spectrumService.permissionStatus == .authorized && isMonitoring {
                Task {
                    await spectrumService.start()
                }
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .spectrum && spectrumService.permissionStatus == .authorized && isMonitoring {
                Task {
                    await spectrumService.start()
                }
            } else if newMode == .zones {
                spectrumService.stop()
            }
        }
        .onChange(of: isMonitoring) { _, newValue in
            if newValue && mode == .spectrum && spectrumService.permissionStatus == .authorized {
                Task {
                    await spectrumService.start()
                }
            } else if !newValue {
                spectrumService.stop()
            }
        }
        .onDisappear {
            spectrumService.stop()
        }
    }
    
    // MARK: - Header with Toggle
    
    private var headerWithToggle: some View {
        VStack(spacing: 12) {
            // Title row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: mode == .spectrum ? "waveform" : "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.primaryFallback)
                    
                    Text(mode == .spectrum ? "Live Spectrum" : "Exposure Zones")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.label)
                }
                
                Spacer()
                
                if mode == .spectrum && spectrumService.isRunning {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.safe)
                            .frame(width: 6, height: 6)
                        Text("On-device")
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
            }
            
            // Centered segmented toggle
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }
    }
    
    // MARK: - Spectrum Content
    
    @ViewBuilder
    private var spectrumContent: some View {
        switch spectrumService.permissionStatus {
        case .authorized:
            if isMonitoring {
                spectrumVisualization
            } else {
                pausedStateView
            }
        case .denied:
            permissionDeniedView
        case .notDetermined:
            requestPermissionView
        }
    }
    
    private var spectrumVisualization: some View {
        VStack(spacing: 16) {
            // Equalizer bars
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        spectrumBar(
                            value: spectrumService.spectrumBands[safe: index] ?? 0,
                            index: index,
                            maxHeight: geo.size.height
                        )
                    }
                }
            }
            .frame(height: 120)
            
            // Current level indicator
            HStack {
                Text("Sound Level")
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
                
                Spacer()
                
                levelIndicator
            }
        }
    }
    
    private func spectrumBar(value: Float, index: Int, maxHeight: CGFloat) -> some View {
        let normalizedValue = CGFloat(max(0.05, min(1.0, value)))
        let barHeight = max(4, normalizedValue * maxHeight)
        
        // Color gradient based on frequency (low = warm, high = cool)
        let hue = Double(index) / Double(barCount) * 0.4 + 0.5 // Blue to purple range
        let barColor = Color(hue: hue, saturation: 0.7, brightness: 0.9)
        
        return RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        barColor.opacity(0.4),
                        barColor,
                        barColor.opacity(0.8)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: barHeight)
            .animation(.easeOut(duration: 0.08), value: value)
    }
    
    private var levelIndicator: some View {
        let level = spectrumService.currentDecibels
        let color: Color = {
            if level < 20 { return AppColors.safe }
            if level < 40 { return AppColors.caution }
            return AppColors.danger
        }()
        
        return HStack(spacing: 8) {
            // Mini level bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(level / 60))
                }
            }
            .frame(width: 60, height: 6)
            
            Text(levelDescription(level))
                .font(AppTypography.caption1Bold)
                .foregroundColor(color)
        }
    }
    
    private func levelDescription(_ level: Float) -> String {
        if level < 15 { return "Quiet" }
        if level < 30 { return "Normal" }
        if level < 45 { return "Moderate" }
        return "Loud"
    }
    
    // MARK: - Paused State
    
    private var pausedStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Faded bars
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: CGFloat.random(in: 20...80))
                    }
                }
                .frame(height: 120)
                
                // Overlay message
                VStack(spacing: 8) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.secondaryLabel)
                    
                    Text("Monitoring Paused")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        }
    }
    
    // MARK: - Permission Views
    
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 40))
                .foregroundColor(AppColors.secondaryLabel)
            
            Text("Microphone Access Needed")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.label)
            
            Text("Enable microphone access in Settings to see the live spectrum visualization.")
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(AppTypography.buttonMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.primaryFallback)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 20)
    }
    
    private var requestPermissionView: some View {
        VStack(spacing: 16) {
            // Animated placeholder bars
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primaryFallback.opacity(0.2), AppColors.primaryFallback.opacity(0.4)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: CGFloat(20 + (index % 5) * 15))
                }
            }
            .frame(height: 100)
            .opacity(0.5)
            
            Text("Tap to enable live spectrum")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.secondaryLabel)
            
            Button {
                Task {
                    await spectrumService.requestPermission()
                    if spectrumService.permissionStatus == .authorized && isMonitoring {
                        await spectrumService.start()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic")
                    Text("Enable Microphone")
                }
                .font(AppTypography.buttonMedium)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.primaryFallback)
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Zones Content
    
    private var zonesContent: some View {
        VStack(spacing: 12) {
            // Current level banner (if available)
            if let level = currentLevelDB {
                currentLevelBanner(level: level)
            }
            
            // Zone bars
            GeometryReader { geo in
                let maxHeight = geo.size.height - 24
                let maxValue = max(1, bands.map(\.seconds).max() ?? 1)
                
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(bands) { band in
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(band.color)
                                .frame(
                                    width: 28,
                                    height: max(4, maxHeight * CGFloat(band.seconds / maxValue))
                                )
                                .animation(.easeInOut(duration: 0.35), value: band.seconds)
                            
                            // dB range label
                            Text(band.label)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(AppColors.tertiaryLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(band.label): \(band.formattedTime)")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 130)
            
            // Legend
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(AppColors.safe).frame(width: 8, height: 8)
                    Text("Safe")
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(AppColors.caution).frame(width: 8, height: 8)
                    Text("Caution")
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(AppColors.danger).frame(width: 8, height: 8)
                    Text("Risk")
                }
            }
            .font(AppTypography.caption2)
            .foregroundColor(AppColors.secondaryLabel)
        }
    }
    
    private func currentLevelBanner(level: Double) -> some View {
        HStack(spacing: 12) {
            // Pulsing indicator
            ZStack {
                Circle()
                    .fill(colorForLevel(level).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(colorForLevel(level).opacity(0.4))
                    .frame(width: 32, height: 32)
                
                Text("\(Int(level))")
                    .font(AppTypography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(colorForLevel(level))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Current Level")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                    
                    Circle()
                        .fill(AppColors.safe)
                        .frame(width: 6, height: 6)
                    
                    Text("Live")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                
                Text("\(Int(level)) dB • \(DoseCalculator.levelDescription(level))")
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.label)
            }
            
            Spacer()
            
            // Risk badge
            Text(riskLabel(for: level))
                .font(AppTypography.caption1Bold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(colorForLevel(level))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorForLevel(level).opacity(0.08))
        )
    }
    
    // MARK: - Styling
    
    private var cardBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.25)
            } else {
                Color.white.opacity(0.95)
            }
        }
        .background(.ultraThinMaterial)
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.glassBorder.opacity(colorScheme == .dark ? 0.2 : 0.4),
                AppColors.glassBorder.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Helpers
    
    private func colorForLevel(_ level: Double) -> Color {
        if level >= 90 { return AppColors.danger }
        if level >= 85 { return AppColors.caution }
        if level >= 70 { return AppColors.caution.opacity(0.8) }
        return AppColors.safe
    }
    
    private func riskLabel(for level: Double) -> String {
        if level >= 100 { return "Extreme" }
        if level >= 90 { return "High Risk" }
        if level >= 85 { return "Risk" }
        if level >= 70 { return "Moderate" }
        return "Safe"
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            PrimaryAudioCard(
                spectrumService: AudioSpectrumService.shared,
                bands: [
                    .init(id: "1", label: "<60", shortLabel: "<60", seconds: 900, color: AppColors.safe),
                    .init(id: "2", label: "60-70", shortLabel: "60-70", seconds: 1200, color: AppColors.safe.opacity(0.85)),
                    .init(id: "3", label: "70-80", shortLabel: "70-80", seconds: 1500, color: AppColors.safe.opacity(0.7)),
                    .init(id: "4", label: "80-85", shortLabel: "80-85", seconds: 600, color: AppColors.caution.opacity(0.85)),
                    .init(id: "5", label: "85-90", shortLabel: "85-90", seconds: 300, color: AppColors.caution),
                    .init(id: "6", label: "90-95", shortLabel: "90-95", seconds: 120, color: AppColors.danger.opacity(0.9)),
                    .init(id: "7", label: "95-100", shortLabel: "95-100", seconds: 60, color: AppColors.danger),
                    .init(id: "8", label: "100+", shortLabel: "100+", seconds: 20, color: AppColors.danger.opacity(0.75)),
                ],
                currentLevelDB: 72,
                isMonitoring: true
            )
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
