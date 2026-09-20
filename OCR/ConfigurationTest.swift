import Foundation
import Combine

extension OpenRouterService {
    static let configurationTestReply = "OCR_OK"

    static func makeConfigurationTestRequest(apiKey: String, model: String,
                                              reasoning: ReasoningEffort) throws -> URLRequest {
        var request = try makeChatRequest(
            content: [["type": "text", "text": "Reply with exactly OCR_OK and nothing else."]],
            apiKey: apiKey, model: model, reasoning: reasoning, stream: false)
        request.timeoutInterval = 30
        return request
    }

    static func validateConfigurationTest(data: Data, status: Int, apiKey: String) throws {
        guard data.count <= 1_048_576 else { throw OCRError.apiError("Test response exceeded the size limit.") }
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = object?["error"] as? [String: Any] {
            let detail = (error["message"] as? String) ?? "The provider rejected the request."
            throw OCRError.apiError("HTTP \(status): \(String(redacted(detail, apiKey: apiKey).prefix(500)))")
        }
        guard status == 200 else { throw OCRError.apiError("OpenRouter returned HTTP \(status).") }
        guard let choices = object?["choices"] as? [[String: Any]], let choice = choices.first,
              choice["finish_reason"] as? String == "stop",
              let message = choice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OCRError.apiError("The request returned no complete text response.")
        }
        guard content.trimmingCharacters(in: .whitespacesAndNewlines) == configurationTestReply else {
            throw OCRError.apiError("The model responded, but not with the expected OCR_OK reply. Received: \(String(redacted(content, apiKey: apiKey).prefix(200)))")
        }
    }

    static func testConfiguration(apiKey: String, model: String, reasoning: ReasoningEffort) async throws {
        let request = try makeConfigurationTestRequest(apiKey: apiKey, model: model, reasoning: reasoning)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw OCRError.invalidResponse }
            try validateConfigurationTest(data: data, status: http.statusCode, apiKey: apiKey)
        } onCancel: { session.invalidateAndCancel() }
    }
}

@MainActor
final class ConfigurationTestController: ObservableObject {
    typealias Operation = @MainActor (String, String, ReasoningEffort) async throws -> Void
    @Published private(set) var isTesting = false
    @Published private(set) var message: String?
    @Published private(set) var succeeded = false
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private let operation: Operation

    init(operation: @escaping Operation = { key, model, effort in
        try await OpenRouterService.testConfiguration(apiKey: key, model: model, reasoning: effort)
    }) { self.operation = operation }

    func start(apiKey: String, model: String, reasoning: ReasoningEffort) {
        guard !isTesting else { return }
        invalidate()
        let current = generation
        let selectedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        isTesting = true
        message = "Testing \(selectedModel) · \(reasoning.displayName)…"
        task = Task {
            let clock = ContinuousClock(); let start = clock.now
            do {
                try await operation(apiKey, selectedModel, reasoning)
                try Task.checkCancellation()
                guard generation == current else { return }
                let duration = start.duration(to: clock.now)
                let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
                succeeded = true
                message = "Success · \(selectedModel) · \(reasoning.displayName) · \(String(format: "%.2fs", seconds)) · Received OCR_OK"
            } catch {
                guard generation == current, !Task.isCancelled else { return }
                succeeded = false
                message = "Test failed: \(OpenRouterService.redacted(error.localizedDescription, apiKey: apiKey))"
            }
            guard generation == current else { return }
            isTesting = false; task = nil
        }
    }

    func invalidate() {
        generation = UUID(); task?.cancel(); task = nil
        isTesting = false; message = nil; succeeded = false
    }
}
