import Foundation

/// Configuration for external API keys
/// IMPORTANT: Create a Secrets.swift file with your actual API key (see README)
enum APIConfig {
    // MARK: - Gemini API

    /// Your Gemini API key - get one at https://aistudio.google.com/app/apikey
    /// Create Secrets.swift with: enum Secrets { static let geminiAPIKey = "YOUR_KEY" }
    static let geminiAPIKey = Secrets.geminiAPIKey

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

