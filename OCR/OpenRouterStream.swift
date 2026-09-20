import Foundation

/// Parses SSE bytes rather than AsyncBytes.lines, which omits empty event delimiters.
/// Hidden reasoning is never retained or forwarded to the UI.
struct OCRStreamParser {
    private var line = Data()
    private var eventLines: [String] = []
    private var eventBytes = 0
    private var outputBytes = 0
    private var previousCR = false
    private(set) var done = false
    private(set) var terminal = false
    private(set) var result = OCRStreamResult()
    private let limit = 2 * 1024 * 1024

    mutating func consume(_ byte: UInt8) throws -> String? {
        try Task.checkCancellation()
        if done { return nil }
        if byte == 10 && previousCR { previousCR = false; return nil }
        previousCR = byte == 13
        if byte == 10 || byte == 13 {
            guard let value = String(data: line, encoding: .utf8) else { throw failure("Invalid UTF-8 in stream.") }
            line.removeAll(keepingCapacity: true)
            if value.isEmpty { return try dispatch() }
            if value.hasPrefix("data:") {
                var payload = String(value.dropFirst(5))
                if payload.first == " " { payload.removeFirst() }
                eventBytes += payload.utf8.count
                guard eventBytes <= limit else { throw failure("Stream event exceeds the size limit.") }
                eventLines.append(payload)
            }
            return nil
        }
        line.append(byte)
        guard line.count <= limit else { throw failure("Stream line exceeds the size limit.") }
        return nil
    }

    mutating func finish() throws -> OCRStreamResult {
        try Task.checkCancellation()
        guard done && terminal else { throw failure("The response stream ended before completion.") }
        return result
    }

    private func failure(_ text: String) -> OCRError { .apiError(text) }

    private mutating func dispatch() throws -> String? {
        guard !eventLines.isEmpty else { return nil }
        let data = eventLines.joined(separator: "\n")
        eventLines.removeAll(keepingCapacity: true); eventBytes = 0
        if data == "[DONE]" {
            guard terminal else { throw failure("Stream ended without a completion reason.") }
            done = true
            return nil
        }
        guard let bytes = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            throw failure("Malformed response stream event.")
        }
        if let error = json["error"], !(error is NSNull) {
            let detail = (error as? [String: Any])?["message"] as? String ?? "Provider returned a streaming error."
            throw failure(detail)
        }
        if let value = json["id"] as? String { result.requestID = value }
        if let value = json["model"] as? String { result.model = value }
        if let value = json["provider"] as? String { result.provider = value }
        if let usage = json["usage"] as? [String: Any] { result.usage = OCRUsage(json: usage) }
        guard let choices = json["choices"] as? [[String: Any]] else {
            guard json["usage"] != nil else { throw failure("Stream event has no choices or usage.") }
            return nil
        }
        guard let choice = choices.first else { return nil }
        if let error = choice["error"], !(error is NSNull) { throw failure("Provider returned a streaming error.") }
        let delta = choice["delta"] as? [String: Any]
        let content = delta?["content"] as? String
        if let content {
            guard !terminal || content.isEmpty else { throw failure("Content arrived after completion.") }
            outputBytes += content.utf8.count
            guard outputBytes <= limit else { throw failure("Response exceeds the size limit.") }
            result.text = (result.text ?? "") + content
        }
        if let finish = choice["finish_reason"] as? String {
            guard finish == "stop" else { throw failure("Response did not complete normally (\(finish)).") }
            terminal = true
        }
        return content
    }
}

extension OpenRouterService {
    static func streamOCR(imageData: Data, apiKey: String, model: String, reasoning: ReasoningEffort,
                          onDelta: @escaping @MainActor (String) -> Void) async throws -> OCRStreamResult {
        let request = try makeRequest(imageData: imageData, apiKey: apiKey, model: model,
                                      reasoning: reasoning, stream: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 180
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let clock = ContinuousClock()
        let start = clock.now
        return try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse else { throw OCRError.invalidResponse }
                guard http.statusCode == 200 else {
                    // Status only: arbitrary HTTP bodies may contain credentials or the input image.
                    throw OCRError.apiError("OpenRouter returned HTTP \(http.statusCode).")
                }
                guard http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("text/event-stream") == true else {
                    throw OCRError.apiError("OpenRouter did not return an event stream.")
                }
                var parser = OCRStreamParser()
                var firstToken: Double?
                for try await byte in bytes {
                    try Task.checkCancellation()
                    if let delta = try parser.consume(byte) {
                        if !delta.isEmpty && firstToken == nil {
                            let duration = start.duration(to: clock.now)
                            firstToken = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
                        }
                        onDelta(delta)
                    }
                    if parser.done { break }
                }
                var result = try parser.finish()
                result.firstTokenSeconds = firstToken
                return result
            } catch {
                if Task.isCancelled { throw CancellationError() }
                throw OCRError.apiError(redacted(error.localizedDescription, apiKey: apiKey))
            }
        } onCancel: {
            session.invalidateAndCancel()
        }
    }
}
