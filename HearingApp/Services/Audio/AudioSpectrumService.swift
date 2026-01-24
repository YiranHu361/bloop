import Foundation
import AVFoundation
import Accelerate
import Combine
import SwiftUI

/// Service that captures microphone input and performs real-time FFT to produce spectrum data.
/// Audio is processed on-device only and never recorded or stored.
@MainActor
final class AudioSpectrumService: ObservableObject {
    static let shared = AudioSpectrumService()
    
    // MARK: - Published State
    
    @Published private(set) var spectrumBands: [Float] = Array(repeating: 0, count: 32)
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var permissionStatus: PermissionStatus = .notDetermined
    @Published private(set) var currentDecibels: Float = 0
    
    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
    }
    
    // MARK: - Audio Engine
    
    private var audioEngine: AVAudioEngine?
    private let fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int = 2048
    private let bandCount: Int = 32
    
    // Smoothing
    private var smoothedBands: [Float]
    private let smoothingFactor: Float = 0.3
    
    // MARK: - Init
    
    private init() {
        smoothedBands = Array(repeating: 0, count: bandCount)
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    // MARK: - Permission
    
    func checkPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionStatus = .authorized
        case .denied:
            permissionStatus = .denied
        case .undetermined:
            permissionStatus = .notDetermined
        @unknown default:
            permissionStatus = .notDetermined
        }
    }
    
    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        await MainActor.run {
            permissionStatus = granted ? .authorized : .denied
        }
        return granted
    }
    
    // MARK: - Start / Stop
    
    func start() async {
        guard !isRunning else { return }
        
        // Check/request permission
        checkPermission()
        if permissionStatus == .notDetermined {
            let granted = await requestPermission()
            if !granted { return }
        } else if permissionStatus == .denied {
            return
        }
        
        do {
            try setupAudioSession()
            try setupAudioEngine()
            isRunning = true
        } catch {
            print("AudioSpectrumService: Failed to start - \(error)")
        }
    }
    
    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isRunning = false
        
        // Reset bands smoothly
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                spectrumBands = Array(repeating: 0, count: bandCount)
                smoothedBands = Array(repeating: 0, count: bandCount)
                currentDecibels = 0
            }
        }
    }
    
    // MARK: - Audio Setup
    
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
    }
    
    private func setupAudioEngine() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0 else {
            throw AudioError.invalidFormat
        }
        
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        engine.prepare()
        try engine.start()
        audioEngine = engine
    }
    
    // MARK: - FFT Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0],
              let fftSetup = fftSetup else { return }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength >= fftSize else { return }
        
        // Copy samples
        var samples = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            samples[i] = channelData[i]
        }
        
        // Apply Hanning window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(fftSize))
        
        // Prepare FFT input/output
        var realIn = [Float](repeating: 0, count: fftSize)
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)
        
        realIn = samples
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &realIn, &imagIn, &realOut, &imagOut)
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<(fftSize / 2) {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }
        
        // Calculate RMS for dB display
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(fftSize))
        let db = 20 * log10(max(rms, 0.0001))
        
        // Bucket into bands (log-spaced)
        let bands = bucketIntoBands(magnitudes: magnitudes)
        
        // Update on main thread with smoothing
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            for i in 0..<self.bandCount {
                self.smoothedBands[i] = self.smoothedBands[i] * (1 - self.smoothingFactor) + bands[i] * self.smoothingFactor
            }
            
            self.spectrumBands = self.smoothedBands
            self.currentDecibels = max(-60, min(0, db + 60)) // Normalize to 0-60 range roughly
        }
    }
    
    private func bucketIntoBands(magnitudes: [Float]) -> [Float] {
        var bands = [Float](repeating: 0, count: bandCount)
        let nyquist = magnitudes.count
        
        // Log-spaced frequency bands
        let minFreqBin = 1
        let maxFreqBin = nyquist - 1
        
        for i in 0..<bandCount {
            let lowRatio = pow(Float(maxFreqBin) / Float(minFreqBin), Float(i) / Float(bandCount))
            let highRatio = pow(Float(maxFreqBin) / Float(minFreqBin), Float(i + 1) / Float(bandCount))
            
            let lowBin = Int(Float(minFreqBin) * lowRatio)
            let highBin = min(Int(Float(minFreqBin) * highRatio), maxFreqBin)
            
            if highBin > lowBin {
                var sum: Float = 0
                for bin in lowBin..<highBin {
                    sum += magnitudes[bin]
                }
                bands[i] = sum / Float(highBin - lowBin)
            }
        }
        
        // Normalize to 0-1 range
        let maxMag = bands.max() ?? 1
        if maxMag > 0 {
            for i in 0..<bandCount {
                bands[i] = min(1.0, bands[i] / maxMag)
            }
        }
        
        return bands
    }
    
    // MARK: - Error
    
    enum AudioError: Error {
        case invalidFormat
        case permissionDenied
    }
}
