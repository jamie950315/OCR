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
    static func performOCR(image: CGImage, apiKey: String, model: String) async throws -> String {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw OCRError.imageConversionFailed
        }
        let base64String = pngData.base64EncodedString()

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Extract all text from this image faithfully. Return tables as GitHub-flavored Markdown tables, preserving the original row and column relationships, headers, empty cells, spelling, punctuation, and spaces within each cell. Preserve line breaks inside a cell using <br>. Escape literal pipe characters inside cells as \\|. For merged cells, put the content only in the top-left cell of the merged region and leave the other covered cells empty. For non-table content, preserve the original text and line breaks; do not convert it into a table. Preserve reading order when text and tables appear together. Return only the extracted content, without explanations or code fences. Do not invent or correct any text."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64String)"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await Self.dataWithRetry(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OCRError.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw OCRError.apiError(message)
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
