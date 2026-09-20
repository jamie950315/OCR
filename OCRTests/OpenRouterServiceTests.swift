import Foundation
import Testing
@testable import OCR

struct OpenRouterServiceTests {
    @MainActor private func parse(_ wire: String) throws -> OCRStreamResult {
        var parser = OCRStreamParser()
        for byte in wire.utf8 { _ = try parser.consume(byte) }
        return try parser.finish()
    }

    @Test @MainActor func reasoningRequestMapping() throws {
        for effort in ReasoningEffort.allCases {
            let request = try OpenRouterService.makeRequest(imageData: Data([0]), apiKey: "test", model: "test/model", reasoning: effort, stream: true)
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
            let reasoning = body["reasoning"] as? [String: Any]
            if effort == .modelDefault { #expect(reasoning == nil) }
            else if effort == .off { #expect(reasoning?["enabled"] as? Bool == false) }
            else { #expect(reasoning?["effort"] as? String == effort.rawValue) }
            #expect(body["stream"] as? Bool == true)
        }
    }

    @Test @MainActor func fragmentedUnicodeCRLFAndTrailingUsage() throws {
        let wire = ": heartbeat\r\n\r\ndata: {\"choices\":[{\"delta\":{\"content\":\"繁中🙂\",\"reasoning\":\"private\"},\"finish_reason\":null}]}\r\n\r\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: {\"choices\":[],\n" +
        "data: \"usage\":{\"prompt_tokens\":3,\"completion_tokens_details\":{\"reasoning_tokens\":4},\"cost\":0.01}}\n\ndata: [DONE]\n\n"
        let result = try parse(wire)
        #expect(result.text == "繁中🙂")
        #expect(result.usage?.promptTokens == 3)
        #expect(result.usage?.reasoningTokens == 4)
        #expect(result.usage?.cost == 0.01)
    }

    @Test @MainActor func rejectsTruncatedMalformedAndErrorStreams() {
        let invalid = [
            "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"},\"finish_reason\":\"stop\"}]}\n\n",
            "data: [DONE]\n\n",
            "data: not-json\n\n",
            "data: {\"error\":{\"message\":\"failure\"}}\n\n",
            "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"length\"}]}\n\ndata: [DONE]\n\n"
        ]
        for wire in invalid { #expect(throws: (any Error).self) { try parse(wire) } }
    }

    @Test @MainActor func nullAndEmptyRemainDistinct() throws {
        let ending = ",\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
        #expect(try parse("data: {\"choices\":[{\"delta\":{\"content\":null}" + ending).text == nil)
        #expect(try parse("data: {\"choices\":[{\"delta\":{\"content\":\"\"}" + ending).text == "")
    }

    @Test @MainActor func cancelledParserStops() async {
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            var parser = OCRStreamParser()
            _ = try parser.consume(100)
        }
        do { try await task.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
    }
}
