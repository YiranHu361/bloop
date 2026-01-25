import Foundation
import AVFoundation
import Combine
import UIKit

/// Monitors the audio output route to detect headphone connections.
/// Used to improve UI state (e.g., "Headphones connected", "No headphones detected").
///
/// Note: iOS cannot reliably tell whether another app is actively playing audio,
/// so "playing" is inferred via recent HealthKit exposure samples.
@MainActor
final class AudioRouteMonitor: ObservableObject {
    static let shared = AudioRouteMonitor()
    
    // MARK: - Published State
    
    @Published private(set) var isHeadphonesConnected: Bool = false
    @Published private(set) var currentOutputType: OutputType = .speaker
    @Published private(set) var deviceName: String?
    
    enum OutputType: String {
        case headphones = "Headphones"
        case bluetoothHeadphones = "Bluetooth Headphones"
        case bluetoothSpeaker = "Bluetooth Speaker"
        case bluetoothUnknown = "Bluetooth Audio"
        case speaker = "Speaker"
        case airplay = "AirPlay"
        case unknown = "Unknown"
        
        var icon: String {
            switch self {
            case .headphones: return "headphones"
            case .bluetoothHeadphones: return "beats.headphones"
            case .bluetoothSpeaker, .bluetoothUnknown: return "hifispeaker"
            case .speaker: return "speaker.wave.2"
            case .airplay: return "airplayaudio"
            case .unknown: return "questionmark.circle"
            }
        }
        
        /// True only for wired headphones and Bluetooth headphones (not BT speakers)
        var isHeadphoneType: Bool {
            switch self {
            case .headphones, .bluetoothHeadphones: return true
            default: return false
            }
        }
        
        /// User-facing display name
        var displayName: String {
            switch self {
            case .headphones: return "Headphones"
            case .bluetoothHeadphones: return "Bluetooth Headphones"
            case .bluetoothSpeaker: return "Bluetooth Speaker"
            case .bluetoothUnknown: return "Bluetooth Audio"
            case .speaker: return "Speaker"
            case .airplay: return "AirPlay"
            case .unknown: return "Unknown"
            }
        }
    }
    
    // MARK: - Private
    
    nonisolated(unsafe) private var routeChangeObserver: NSObjectProtocol?
    nonisolated(unsafe) private var appActiveObserver: NSObjectProtocol?
    
    // MARK: - Init
    
    private init() {
        configureAudioSession()
        checkCurrentRoute()
        startMonitoring()
    }
    
    /// Configure audio session to receive route change notifications.
    /// Uses ambient category with mix mode to avoid interrupting other audio.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal - route detection may still work via notifications
        }
    }
    
    deinit {
        // Clean up observers directly since deinit runs in nonisolated context
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = appActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public API
    
    /// Force a refresh of the current audio route
    func refresh() {
        checkCurrentRoute()
    }
    
    // MARK: - Route Detection
    
    private func checkCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        // Check all outputs
        var foundHeadphones = false
        var outputType: OutputType = .speaker
        var name: String?
        
        for output in currentRoute.outputs {
            let type = classifyPort(output.portType, portName: output.portName)
            
            if type.isHeadphoneType {
                foundHeadphones = true
                outputType = type
                name = output.portName
                break
            } else if type != .speaker {
                outputType = type
                name = output.portName
            }
        }
        
        // If no outputs found, default to speaker
        if currentRoute.outputs.isEmpty {
            outputType = .speaker
        }
        
        isHeadphonesConnected = foundHeadphones
        currentOutputType = outputType
        deviceName = name
    }
    
    /// Classify a port type, using the port name to distinguish BT headphones from BT speakers
    private func classifyPort(_ portType: AVAudioSession.Port, portName: String) -> OutputType {
        switch portType {
        case .headphones, .headsetMic:
            return .headphones
            
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            return classifyBluetoothDevice(portName: portName)
            
        case .builtInSpeaker, .builtInReceiver:
            return .speaker
            
        case .airPlay:
            return .airplay
            
        default:
            // Check for common Bluetooth device patterns in port type string
            let portTypeString = portType.rawValue.lowercased()
            if portTypeString.contains("bluetooth") {
                return classifyBluetoothDevice(portName: portName)
            }
            return .unknown
        }
    }
    
    /// Use heuristics on device name to classify Bluetooth devices as headphones or speakers.
    /// Permissive approach: unknown BT devices default to headphones (most common use case).
    private func classifyBluetoothDevice(portName: String) -> OutputType {
        let nameLower = portName.lowercased()
        
        // Known speaker patterns - check these FIRST to exclude them
        let speakerPatterns = [
            "speaker", "soundbar", "soundlink",
            "homepod", "echo", "alexa",
            "sonos", "bose soundlink", "jbl flip", "jbl charge", "jbl xtreme",
            "ue boom", "megaboom", "wonderboom",
            "marshall", "harman kardon",
            "pill",  // Beats Pill
            "soundcore",
            "anker soundcore",
            "boombox",
        ]
        
        // Check for speaker patterns first - exclude these
        for pattern in speakerPatterns {
            if nameLower.contains(pattern) {
                return .bluetoothSpeaker
            }
        }
        
        // Everything else is assumed to be headphones
        // This is more permissive but matches user expectations (AirPods, etc.)
        return .bluetoothHeadphones
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Observe route changes
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleRouteChange(notification)
            }
        }
        
        // Also observe interruptions (e.g., phone calls)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkCurrentRoute()
            }
        }
        
        // Refresh route when app becomes active (route may have changed in background)
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Re-configure session in case it was deactivated
                self?.configureAudioSession()
                self?.checkCurrentRoute()
            }
        }
    }
    
    private func stopMonitoring() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
        if let observer = appActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            appActiveObserver = nil
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            checkCurrentRoute()
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange, .override, .routeConfigurationChange:
            checkCurrentRoute()
        default:
            break
        }
    }
}
