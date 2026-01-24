import Foundation

/// Centralized feature flags for bloop.
/// These control features that differ between Debug and Release builds.
enum FeatureFlags {
    
    // MARK: - Microphone / Spectrum Features
    
    /// Whether the live spectrum visualization (microphone-based) is enabled.
    /// This feature is Debug-only to maintain privacy in Release builds.
    /// - Note: Release builds must NOT request microphone permission or show mic-related UI.
    static var micSpectrumEnabled: Bool {
        #if DEBUG
        return _debugMicSpectrumOverride ?? true
        #else
        return false
        #endif
    }
    
    #if DEBUG
    /// Debug-only override for mic spectrum feature.
    /// Set to `false` to test Release behavior in Debug builds.
    private static var _debugMicSpectrumOverride: Bool? = nil
    
    /// Override mic spectrum feature flag (Debug only).
    static func setMicSpectrumEnabled(_ enabled: Bool?) {
        _debugMicSpectrumOverride = enabled
    }
    #endif
    
    // MARK: - Debug Features
    
    /// Whether debug tools are available (sample data generation, etc.)
    static var debugToolsEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Whether verbose logging is enabled
    static var verboseLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Feature Gate Helpers
    
    /// Execute a closure only if mic spectrum is enabled
    @discardableResult
    static func whenMicSpectrumEnabled<T>(_ block: () -> T) -> T? {
        guard micSpectrumEnabled else { return nil }
        return block()
    }
    
    /// Execute a closure only if mic spectrum is enabled (async version)
    @discardableResult
    static func whenMicSpectrumEnabled<T>(_ block: () async -> T) async -> T? {
        guard micSpectrumEnabled else { return nil }
        return await block()
    }
}
