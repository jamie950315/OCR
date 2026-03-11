import Foundation
import AppKit

enum OCRError: LocalizedError {
    case imageConversionFailed
    case invalidResponse
    case apiError(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "圖片轉換失敗"
        case .invalidResponse: return "無效的 API 回應"
        case .apiError(let message): return message
        case .noContent: return "API 回應中沒有內容"
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
                            "text": "Extract all text from this image. Return only the raw text content, preserving the original structure and layout. Do not add any explanations, commentary, or formatting that isn't in the original image."
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

        let (data, response) = try await URLSession.shared.data(for: request)

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
}
