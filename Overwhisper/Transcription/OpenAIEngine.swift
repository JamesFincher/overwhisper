import Foundation

struct OpenAIEngine: TranscriptionEngine {
    private let apiKey: String
    private let translateToEnglish: Bool
    private let language: String
    private let customVocabulary: String
    private static let requestTimeoutSeconds: TimeInterval = 30

    private var baseURL: String {
        translateToEnglish
            ? "https://api.openai.com/v1/audio/translations"
            : "https://api.openai.com/v1/audio/transcriptions"
    }

    init(apiKey: String, translateToEnglish: Bool = false, language: String = "auto", customVocabulary: String = "") {
        self.apiKey = apiKey
        self.translateToEnglish = translateToEnglish
        self.language = language
        self.customVocabulary = customVocabulary
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = Self.makeMultipartBody(
            audioData: audioData,
            boundary: boundary,
            language: requestLanguage,
            customVocabulary: customVocabulary
        )

        request.httpBody = body

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error.message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        // Parse response
        let transcriptionResponse = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)

        return transcriptionResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var requestLanguage: String? {
        Self.resolvedRequestLanguage(language, translateToEnglish: translateToEnglish)
    }

    static func resolvedRequestLanguage(_ language: String, translateToEnglish: Bool) -> String? {
        guard !translateToEnglish else { return nil }

        let trimmedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLanguage.isEmpty, trimmedLanguage != "auto" else { return nil }

        return trimmedLanguage
    }

    static func makeMultipartBody(
        audioData: Data,
        boundary: String,
        language: String?,
        customVocabulary: String
    ) -> Data {
        var body = Data()

        appendFileField(audioData, to: &body, boundary: boundary)
        appendFormField(name: "model", value: "whisper-1", to: &body, boundary: boundary)
        appendFormField(name: "response_format", value: "json", to: &body, boundary: boundary)

        if let language {
            appendFormField(name: "language", value: language, to: &body, boundary: boundary)
        }

        if !customVocabulary.isEmpty {
            appendFormField(name: "prompt", value: customVocabulary, to: &body, boundary: boundary)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private static func appendFileField(_ audioData: Data, to body: inout Data, boundary: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
    }

    private static func appendFormField(name: String, value: String, to body: inout Data, boundary: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }
}

struct OpenAITranscriptionResponse: Codable {
    let text: String
}

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not configured"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        case .decodingError:
            return "Failed to decode API response"
        }
    }
}
