import Foundation
import Testing
@testable import OCR

struct ConfigurationTestTests {
    @Test @MainActor func usesCurrentModelAndReasoningWithoutAnImage() throws {
        for effort in ReasoningEffort.allCases {
            let request = try OpenRouterService.makeConfigurationTestRequest(apiKey: "fake", model: "qwen/qwen3.8-flash", reasoning: effort)
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
            #expect(body["model"] as? String == "qwen/qwen3.8-flash")
            #expect(body["stream"] as? Bool == false)
            let messages = try #require(body["messages"] as? [[String: Any]])
            let content = try #require(messages.first?["content"] as? [[String: Any]])
            #expect(content.count == 1)
            #expect(content.first?["type"] as? String == "text")
            let reasoning = body["reasoning"] as? [String: Any]
            if effort == .off { #expect(reasoning?["enabled"] as? Bool == false) }
            else if effort == .modelDefault { #expect(reasoning == nil) }
            else { #expect(reasoning?["effort"] as? String == effort.rawValue) }
        }
    }

    @Test @MainActor func validatesContentNotOnlyHTTPStatus() throws {
        func response(_ content: Any, finish: String = "stop") throws -> Data {
            try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content], "finish_reason": finish]]])
        }
        try OpenRouterService.validateConfigurationTest(data: response(" OCR_OK\n"), status: 200, apiKey: "fake")
        for body in [try response("Wrong"), try response(NSNull()), try response("OCR_OK", finish: "length"), Data("not JSON".utf8)] {
            #expect(throws: (any Error).self) { try OpenRouterService.validateConfigurationTest(data: body, status: 200, apiKey: "fake") }
        }
        let failure = try JSONSerialization.data(withJSONObject: ["error": ["message": "Rejected private-key"]])
        do { try OpenRouterService.validateConfigurationTest(data: failure, status: 401, apiKey: "private-key"); Issue.record("Expected rejection") }
        catch { #expect(!error.localizedDescription.contains("private-key")); #expect(error.localizedDescription.contains("401")) }
    }

    @Test @MainActor func cancellationInvalidatesLateResults() async throws {
        var continuation: CheckedContinuation<Void, Never>?
        let controller = ConfigurationTestController { _, _, _ in
            await withCheckedContinuation { continuation = $0 }
        }
        controller.start(apiKey: "fake", model: "test/model", reasoning: .low)
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        let pending = try #require(continuation)
        controller.invalidate()
        pending.resume()
        for _ in 0..<10 { await Task.yield() }
        #expect(!controller.isTesting)
        #expect(controller.message == nil)
        #expect(!controller.succeeded)
    }

    @Test @MainActor func displaysSuccessAndRedactsErrors() async {
        let success = ConfigurationTestController { _, _, _ in }
        success.start(apiKey: "fake", model: "test/model", reasoning: .medium)
        for _ in 0..<100 where success.isTesting { await Task.yield() }
        #expect(success.succeeded)
        #expect(success.message?.contains("Medium") == true)
        let failure = ConfigurationTestController { key, _, _ in throw OCRError.apiError("Rejected \(key)") }
        failure.start(apiKey: "private-key", model: "test/model", reasoning: .low)
        for _ in 0..<100 where failure.isTesting { await Task.yield() }
        #expect(!failure.isTesting)
        #expect(failure.message?.contains("private-key") == false)
        #expect(failure.message?.contains("[REDACTED]") == true)
    }
}
