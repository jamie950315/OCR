import Foundation
import Testing
@testable import OCR

struct BenchmarkStoreTests {
    @Test func incompatibleRunRemainsInspectableAndCorruptFileDoesNotHideValidRun() throws {
        let dataset = try BenchmarkDataset.load()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BenchmarkStore(directory: directory)
        let run = fixture(dataset)
        var object = try JSONSerialization.jsonObject(with: BenchmarkStore.encode(run)) as! [String: Any]
        object["datasetID"] = "historic-dataset"
        let imported = try store.validatedImport(data: JSONSerialization.data(withJSONObject: object), dataset: dataset)
        #expect(imported.datasetID == "historic-dataset")
        try store.save(imported)
        try Data("not JSON".utf8).write(to: directory.appendingPathComponent("corrupt.json"))
        let loaded = try store.loadWithWarnings(dataset: dataset)
        #expect(loaded.runs.count == 1)
        #expect(loaded.warnings.count == 1)
        object["model"] = 42
        #expect(throws: (any Error).self) { try store.validatedImport(data: JSONSerialization.data(withJSONObject: object), dataset: dataset) }
    }
    private func fixture(_ dataset: BenchmarkDataset) -> BenchmarkRun {
        BenchmarkRun(id: UUID(), startedAt: Date(timeIntervalSince1970: 100), finishedAt: Date(timeIntervalSince1970: 101),
            status: .cancelled, model: "test/model", reasoning: .low, datasetID: dataset.id,
            datasetTitle: dataset.title, datasetCount: dataset.problems.count,
            evaluatorVersion: BenchmarkScorer.version, prompt: "test", promptHash: BenchmarkScorer.promptHash("test"), appVersion: "test", results: [])
    }

    @Test func roundTripPartialRunAndRejectRanking() throws {
        let dataset = try BenchmarkDataset.load()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BenchmarkStore(directory: directory)
        let run = fixture(dataset)
        try store.save(run)
        let loaded = try store.load(dataset: dataset)
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == run.id)
        #expect(BenchmarkStore.comparisonIssue([run, run]) == "Partial or failed runs cannot be ranked.")
    }

    @Test func rejectsRunningAndForgedPromptHash() throws {
        let dataset = try BenchmarkDataset.load()
        let store = BenchmarkStore()
        var run = fixture(dataset); run.status = .running
        #expect(throws: (any Error).self) { try store.validatedImport(data: BenchmarkStore.encode(run), dataset: dataset) }
        run.status = .cancelled
        var object = try JSONSerialization.jsonObject(with: BenchmarkStore.encode(run)) as! [String: Any]
        object["promptHash"] = "forged"
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try store.validatedImport(data: data, dataset: dataset) }
    }

    @Test func rescoringDiscardsForgedScoreAndRejectsDuplicateIDs() throws {
        let dataset = try BenchmarkDataset.load()
        let problem = try #require(dataset.problems.first(where: { $0.kind == "plain" }))
        var run = fixture(dataset)
        let item = BenchmarkCaseResult(problemID: problem.id, title: "forged", category: "forged", kind: "plain",
            status: .completed, response: "definitely incorrect", error: nil, durationSeconds: 1,
            firstTokenSeconds: 0.1, provider: nil, responseModel: nil, requestID: nil, usage: nil,
            score: BenchmarkScore(passed: true, characterEdits: 0, expectedCharacters: 1, notes: []))
        run.results = [item]
        let store = BenchmarkStore()
        let imported = try store.validatedImport(data: BenchmarkStore.encode(run), dataset: dataset)
        #expect(imported.results.first?.score?.passed == false)
        #expect(imported.results.first?.title == problem.title)
        run.results = [item, item]
        #expect(throws: (any Error).self) { try store.validatedImport(data: BenchmarkStore.encode(run), dataset: dataset) }
    }
}
