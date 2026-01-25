import Foundation

/// Configuration for external API keys
/// IMPORTANT: Replace the placeholder with your actual API key before use
enum APIConfig {
    // MARK: - Gemini API

    /// Your Gemini API key - get one at https://aistudio.google.com/app/apikey
    /// Replace "YOUR_GEMINI_API_KEY_HERE" with your actual key
    static let geminiAPIKey = "AIzaSyBByEplgaXaZzarvontBrLC-UgM9WXSsjY"

    /// Gemini API base URL
    static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta"

    /// Gemini model to use (2.0-flash is fast and efficient)
    static let geminiModel = "gemini-2.0-flash"

    // MARK: - Validation

    /// Check if the API key has been configured
    static var isGeminiConfigured: Bool {
        !geminiAPIKey.isEmpty && geminiAPIKey != "YOUR_GEMINI_API_KEY_HERE"
    }
}

