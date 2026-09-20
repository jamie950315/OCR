import Foundation
import AppKit

enum OCRError: LocalizedError {
    case imageConversionFailed
    case invalidResponse
    case apiError(String)
    case noContent

    var errorDescription: String? {
        let lm = LocalizationManager.shared
        switch self {
        case .imageConversionFailed: return lm.t("error.image_conversion")
        case .invalidResponse:       return lm.t("error.invalid_response")
        case .apiError(let message): return message
        case .noContent:             return lm.t("error.no_content")
        }
    }
}

struct OpenRouterService {
    static let ocrPrompt = "Extract all text from this image faithfully. Return tables as GitHub-flavored Markdown tables, preserving the original row and column relationships, headers, empty cells, spelling, punctuation, and spaces within each cell. Preserve line breaks inside a cell using <br>. Escape literal pipe characters inside cells as \\|. For merged cells, put the content only in the top-left cell of the merged region and leave the other covered cells empty. For non-table content, preserve the original text and line breaks; do not convert it into a table. Preserve reading order when text and tables appear together. Return only the extracted content, without explanations or code fences. Do not invent or correct any text."

    static func makeRequest(imageData: Data, apiKey: String, model: String,
                            reasoning: ReasoningEffort, stream: Bool) throws -> URLRequest {
        try makeChatRequest(content: [
            ["type": "text", "text": ocrPrompt],
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(imageData.base64EncodedString())"]]
        ], apiKey: apiKey, model: model, reasoning: reasoning, stream: stream)
    }

    static func makeChatRequest(content: [[String: Any]], apiKey: String, model: String,
                                reasoning: ReasoningEffort, stream: Bool) throws -> URLRequest {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.apiError("An OpenRouter API key is required.")
        }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.apiError("A model ID is required.")
        }
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        var body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]

        if let value = reasoning.requestValue { body["reasoning"] = value }
        body["stream"] = stream
        if stream { request.setValue("text/event-stream", forHTTPHeaderField: "Accept") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func performOCR(image: CGImage, apiKey: String, model: String,
                           reasoning: ReasoningEffort = .low) async throws -> String {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw OCRError.imageConversionFailed
        }
        let request = try makeRequest(imageData: pngData, apiKey: apiKey, model: model,
                                      reasoning: reasoning, stream: false)

        let (data, response) = try await Self.dataWithRetry(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OCRError.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw OCRError.apiError(redacted(message, apiKey: apiKey))
        }

        guard httpResponse.statusCode == 200 else {
            throw OCRError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OCRError.noContent
        }

        return content
    }

    static func redacted(_ message: String, apiKey: String) -> String {
        apiKey.isEmpty ? message : message.replacingOccurrences(of: apiKey, with: "[REDACTED]")
    }

    private static func dataWithRetry(for request: URLRequest, maxAttempts: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await URLSession.shared.data(for: request)
            } catch let error as URLError where error.code == .secureConnectionFailed
                || error.code == .serverCertificateUntrusted
                || error.code == .timedOut
                || error.code == .networkConnectionLost {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError!
    }
}
