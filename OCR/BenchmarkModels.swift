import Foundation

nonisolated struct BenchmarkProblem: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let category: String
    let kind: String
    let imageName: String
    let expectedText: String?
    let whitespace: String?
    let tables: [[[String]]]?
    let proseGaps: [String]?
}

nonisolated struct BenchmarkDataset: Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let problems: [BenchmarkProblem]
}

nonisolated struct BenchmarkScore: Codable, Sendable {
    let passed: Bool
    let characterEdits: Int
    let expectedCharacters: Int
    let notes: [String]

    var characterErrorRate: Double {
        Double(characterEdits) / Double(max(1, expectedCharacters))
    }
}

nonisolated enum BenchmarkCaseStatus: String, Codable, Sendable {
    case completed, failed, cancelled
}

nonisolated struct BenchmarkCaseResult: Codable, Identifiable, Sendable {
    var id: String { problemID }
    let problemID: String
    let title: String
    let category: String
    let kind: String
    let status: BenchmarkCaseStatus
    let response: String?
    let error: String?
    let durationSeconds: Double
    let firstTokenSeconds: Double?
    let provider: String?
    let responseModel: String?
    let requestID: String?
    let usage: OCRUsage?
    let score: BenchmarkScore?
}

nonisolated enum BenchmarkRunStatus: String, Codable, Sendable {
    case running, completed, cancelled, failed
}

nonisolated struct BenchmarkRun: Codable, Identifiable, Sendable {
    var schemaVersion = 1
    let id: UUID
    let startedAt: Date
    var finishedAt: Date?
    var status: BenchmarkRunStatus
    let model: String
    let reasoning: ReasoningEffort
    let datasetID: String
    let datasetTitle: String
    let datasetCount: Int
    let evaluatorVersion: String
    let prompt: String
    let promptHash: String
    var transportVersion = "sse-v1"
    let appVersion: String
    var results: [BenchmarkCaseResult]

    var processedCount: Int { results.filter { $0.status != .cancelled }.count }
    var passedCount: Int { results.filter { $0.status == .completed && $0.score?.passed == true }.count }
    var isComplete: Bool {
        status == .completed && results.count == datasetCount && results.allSatisfy { $0.status == .completed }
    }
    var medianSeconds: Double? {
        let times = results.filter { $0.status != .cancelled }.map(\.durationSeconds).sorted()
        guard !times.isEmpty else { return nil }
        let middle = times.count / 2
        return times.count.isMultiple(of: 2) ? (times[middle - 1] + times[middle]) / 2 : times[middle]
    }
    var reportedCost: Double? {
        let values = results.compactMap { $0.usage?.upstreamCost ?? $0.usage?.cost }
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    var comparisonKey: String { [datasetID, evaluatorVersion, promptHash, transportVersion].joined(separator: ":") }
}
