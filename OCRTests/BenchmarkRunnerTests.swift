import Foundation
import Testing
@testable import OCR

struct BenchmarkRunnerTests {
    @Test @MainActor func errorDoesNotExposeAPIKey() async throws {
        struct UnsafeError: LocalizedError { var errorDescription: String? { "bad request secret-test-key" } }
        let dataset = try BenchmarkDataset.load()
        let runner = BenchmarkRunner { _, _, _, _, _ in throw UnsafeError() }
        runner.start(dataset: dataset, model: "test", reasoning: .low, apiKey: "secret-test-key", imageLoader: { _ in Data() })
        while runner.isRunning { await Task.yield() }
        #expect(runner.errorMessage?.contains("secret-test-key") == false)
        #expect(runner.run?.results.first?.error?.contains("secret-test-key") == false)
    }
    @Test @MainActor func completesAllProblemsWithStreamAndScores() async {
        let problems = (1...2).map { BenchmarkProblem(id: "p\($0)", title: "Plain", category: "text", kind: "plain", imageName: "unused.png", expectedText: "hello", whitespace: "lines", tables: nil, proseGaps: nil) }
        let dataset = BenchmarkDataset(id: "test", title: "Test", description: "Test", problems: problems)
        var calls = 0
        let runner = BenchmarkRunner { _, _, model, effort, delta in
            #expect(model == "test/model"); #expect(effort == .low)
            calls += 1; delta("hel"); delta("lo")
            return OCRStreamResult(text: "hello", model: model, provider: "test", requestID: nil, usage: nil, firstTokenSeconds: 0)
        }
        runner.start(dataset: dataset, model: "test/model", reasoning: .low, apiKey: "fake", imageLoader: { _ in Data() })
        while runner.isRunning { await Task.yield() }
        #expect(calls == 2)
        #expect(runner.run?.isComplete == true)
        #expect(runner.run?.passedCount == 2)
        #expect(runner.currentResponse == "hello")
    }
    @Test @MainActor func stopsAfterFirstTransportFailure() async throws {
        let dataset = try BenchmarkDataset.load()
        var calls = 0
        let runner = BenchmarkRunner { _, _, _, _, delta in
            calls += 1; delta("partial")
            throw URLError(.badServerResponse)
        }
        runner.start(dataset: dataset, model: "test/model", reasoning: .low, apiKey: "not-a-real-key", imageLoader: { _ in Data() })
        while runner.isRunning { await Task.yield() }
        #expect(calls == 1)
        #expect(runner.run?.status == .failed)
        #expect(runner.run?.results.count == 1)
        #expect(runner.run?.results.first?.response == "partial")
    }

    @Test @MainActor func cancellationStopsCurrentRequestAndKeepsPartialResponse() async throws {
        let dataset = try BenchmarkDataset.load()
        let runner = BenchmarkRunner { _, _, _, _, delta in
            delta("started")
            try await Task.sleep(for: .seconds(30))
            throw URLError(.unknown)
        }
        runner.start(dataset: dataset, model: "test/model", reasoning: .off, apiKey: "not-a-real-key", imageLoader: { _ in Data() })
        while runner.currentResponse.isEmpty { await Task.yield() }
        runner.cancel()
        while runner.isRunning { await Task.yield() }
        #expect(runner.run?.status == .cancelled)
        #expect(runner.run?.results.first?.response == "started")
        #expect(runner.run?.processedCount == 0)
    }
}
