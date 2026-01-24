import SwiftUI

/// Live frequency spectrum visualization (equalizer bars) driven by microphone input.
/// Audio is processed on-device only and never recorded.
struct LiveSpectrumView: View {
    @ObservedObject var spectrumService: AudioSpectrumService
    let isMonitoring: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasRequestedPermission = false
    
    private let barCount = 32
    private let barSpacing: CGFloat = 3
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            headerView
            
            // Main content
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
            if spectrumService.permissionStatus == .authorized && isMonitoring {
                Task {
                    await spectrumService.start()
                }
            }
        }
        .onChange(of: isMonitoring) { _, newValue in
            if newValue && spectrumService.permissionStatus == .authorized {
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
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryFallback)
                
                Text("Live Spectrum")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)
            }
            
            Spacer()
            
            if spectrumService.isRunning {
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
    }
    
    // MARK: - Spectrum Visualization
    
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
    
    // MARK: - Permission Denied
    
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
    
    // MARK: - Request Permission
    
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
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LiveSpectrumView(
            spectrumService: AudioSpectrumService.shared,
            isMonitoring: true
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
