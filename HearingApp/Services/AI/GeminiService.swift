import Foundation

/// Service for interacting with Google's Gemini API for AI-powered insights
actor GeminiService {
    static let shared = GeminiService()

    private init() {}

    // MARK: - Types

    struct GeminiRequest: Codable {
        let contents: [Content]
        let generationConfig: GenerationConfig?

        struct Content: Codable {
            let parts: [Part]
        }

        struct Part: Codable {
            let text: String
        }

        struct GenerationConfig: Codable {
            let temperature: Double?
            let maxOutputTokens: Int?
        }
    }

    struct GeminiResponse: Codable {
        let candidates: [Candidate]?
        let error: GeminiError?

        struct Candidate: Codable {
            let content: Content?

            struct Content: Codable {
                let parts: [Part]?

                struct Part: Codable {
                    let text: String?
                }
            }
        }

        struct GeminiError: Codable {
            let message: String?
            let status: String?
        }
    }

    enum GeminiServiceError: Error, LocalizedError {
        case notConfigured
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Gemini API key not configured. Please add your API key in APIConfig.swift"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from Gemini API"
            case .apiError(let message):
                return "Gemini API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public Methods

    /// Generate a personalized hearing insight based on the user's current dose and listening patterns
    func generateHearingInsight(
        dosePercent: Double,
        burnRatePerHour: Double,
        etaMinutes: Double?,
        isActivelyListening: Bool,
        averageDB: Double?,
        peakDB: Double?
    ) async throws -> String {
        guard APIConfig.isGeminiConfigured else {
            throw GeminiServiceError.notConfigured
        }

        let prompt = buildHearingInsightPrompt(
            dosePercent: dosePercent,
            burnRatePerHour: burnRatePerHour,
            etaMinutes: etaMinutes,
            isActivelyListening: isActivelyListening,
            averageDB: averageDB,
            peakDB: peakDB
        )

        return try await generateText(prompt: prompt)
    }

    /// Generate a general text response from Gemini
    func generateText(prompt: String) async throws -> String {
        return try await generateText(prompt: prompt, temperature: 0.7, maxOutputTokens: 150)
    }

    /// Generate a text response with custom generation config
    func generateText(
        prompt: String,
        temperature: Double,
        maxOutputTokens: Int
    ) async throws -> String {
        guard APIConfig.isGeminiConfigured else {
            throw GeminiServiceError.notConfigured
        }

        let url = URL(string: "\(APIConfig.geminiBaseURL)/models/\(APIConfig.geminiModel):generateContent?key=\(APIConfig.geminiAPIKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GeminiRequest(
            contents: [
                GeminiRequest.Content(parts: [GeminiRequest.Part(text: prompt)])
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: temperature,
                maxOutputTokens: maxOutputTokens
            )
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let errorMessage = errorResponse.error?.message {
                throw GeminiServiceError.apiError(errorMessage)
            }
            throw GeminiServiceError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
        } catch {
            throw GeminiServiceError.decodingError(error)
        }

        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw GeminiServiceError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Methods

    private func buildHearingInsightPrompt(
        dosePercent: Double,
        burnRatePerHour: Double,
        etaMinutes: Double?,
        isActivelyListening: Bool,
        averageDB: Double?,
        peakDB: Double?
    ) -> String {
        var context = """
        You are a friendly hearing health assistant. Generate a brief, actionable insight (1-2 sentences max) about the user's hearing health based on their current data.

        Current hearing data:
        - Daily hearing dose: \(Int(dosePercent))% (100% = WHO daily safe limit)
        - Currently listening: \(isActivelyListening ? "Yes" : "No")
        """

        if burnRatePerHour > 0 {
            context += "\n- Burn rate: \(String(format: "%.1f", burnRatePerHour))% per hour"
        }

        if let eta = etaMinutes {
            if eta <= 0 {
                context += "\n- Status: Daily limit exceeded"
            } else {
                let hours = Int(eta) / 60
                let mins = Int(eta) % 60
                if hours > 0 {
                    context += "\n- Time until daily limit: \(hours)h \(mins)m"
                } else {
                    context += "\n- Time until daily limit: \(mins) minutes"
                }
            }
        }

        if let avg = averageDB {
            context += "\n- Average listening level: \(Int(avg)) dB"
        }

        if let peak = peakDB {
            context += "\n- Peak level today: \(Int(peak)) dB"
        }

        context += """


        Guidelines for response:
        - Keep it under 25 words
        - Be encouraging but honest
        - If dose is high (>80%), suggest a break
        - If dose is moderate (50-80%), acknowledge progress
        - If dose is low (<50%), be encouraging
        - Don't use technical jargon
        - Don't mention exact percentages, use natural language
        - Sound friendly and supportive, not alarming

        Generate the insight now:
        """

        return context
    }
}
