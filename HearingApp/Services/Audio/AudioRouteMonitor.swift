import Foundation
import AVFoundation
import Combine

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
    
    // MARK: - Init
    
    private init() {
        checkCurrentRoute()
        startMonitoring()
    }
    
    deinit {
        // Clean up observer directly since deinit runs in nonisolated context
        if let observer = routeChangeObserver {
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
    /// Conservative approach: unknown BT devices default to NOT headphones (matches HealthKit semantics).
    private func classifyBluetoothDevice(portName: String) -> OutputType {
        let nameLower = portName.lowercased()
        
        // Known headphone patterns (AirPods, Beats, common earbuds/headphones)
        let headphonePatterns = [
            "airpod", "airpods",
            "beats", "powerbeats", "beatsx", "beats fit", "beats studio buds",
            "buds", "earbuds", "earbud",
            "headphone", "headphones", "headset",
            "wh-1000", "wf-1000",  // Sony headphones
            "qc35", "qc45", "nc700",  // Bose headphones
            "px7", "px8",  // Bowers & Wilkins
            "momentum",  // Sennheiser
            "freebuds",  // Huawei
            "galaxy buds",  // Samsung
            "jabra elite",
            "nothing ear",
            "pixel buds",
        ]
        
        // Known speaker patterns
        let speakerPatterns = [
            "speaker", "soundbar", "soundlink",
            "homepod", "echo", "alexa",
            "sonos", "bose soundlink", "jbl",
            "ue boom", "megaboom", "wonderboom",
            "marshall", "harman kardon",
            "flip", "charge", "xtreme",  // JBL portable speakers
            "pill",  // Beats Pill
            "soundcore",
            "anker",
        ]
        
        // Check for headphone patterns first
        for pattern in headphonePatterns {
            if nameLower.contains(pattern) {
                return .bluetoothHeadphones
            }
        }
        
        // Then check for speaker patterns
        for pattern in speakerPatterns {
            if nameLower.contains(pattern) {
                return .bluetoothSpeaker
            }
        }
        
        // Default: unknown Bluetooth device - conservative approach, NOT headphones
        // This aligns with HealthKit's "headphone audio exposure" semantics
        return .bluetoothUnknown
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
    }
    
    private func stopMonitoring() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
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
            
            // Log for debugging
            if FeatureFlags.verboseLoggingEnabled {
                print("AudioRouteMonitor: Route changed - \(reason.description)")
                print("AudioRouteMonitor: Headphones connected: \(isHeadphonesConnected)")
                print("AudioRouteMonitor: Output type: \(currentOutputType.rawValue)")
                if let name = deviceName {
                    print("AudioRouteMonitor: Device name: \(name)")
                }
            }
            
        default:
            break
        }
    }
}

// MARK: - Route Change Reason Description

extension AVAudioSession.RouteChangeReason {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .newDeviceAvailable: return "New device available"
        case .oldDeviceUnavailable: return "Old device unavailable"
        case .categoryChange: return "Category change"
        case .override: return "Override"
        case .wakeFromSleep: return "Wake from sleep"
        case .noSuitableRouteForCategory: return "No suitable route"
        case .routeConfigurationChange: return "Configuration change"
        @unknown default: return "Unknown (\(rawValue))"
        }
    }
}
