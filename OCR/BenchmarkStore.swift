import Foundation

nonisolated struct BenchmarkStore: Sendable {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OCR/Benchmarks", isDirectory: true)
    }

    static func encode(_ run: BenchmarkRun) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(run)
    }

    func save(_ run: BenchmarkRun) throws {
        guard run.status != .running else { throw StoreError.invalid("Cannot save an active run.") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encode(run).write(to: directory.appendingPathComponent(run.id.uuidString + ".json"), options: .atomic)
    }

    func load(dataset: BenchmarkDataset) throws -> [BenchmarkRun] {
        try loadWithWarnings(dataset: dataset).runs
    }

    func loadWithWarnings(dataset: BenchmarkDataset) throws -> (runs: [BenchmarkRun], warnings: [String]) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return ([], []) }
        var runs: [BenchmarkRun] = []; var warnings: [String] = []
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            do {
                let run = try validatedImport(url: url, dataset: dataset)
                guard !runs.contains(where: { $0.id == run.id }) else { throw StoreError.invalid("Duplicate saved run ID.") }
                runs.append(run)
            }
            catch { warnings.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        return (runs.sorted { $0.startedAt > $1.startedAt }, warnings)
    }

    func validatedImport(url: URL, dataset: BenchmarkDataset) throws -> BenchmarkRun {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 20 * 1024 * 1024 else { throw StoreError.invalid("Benchmark file exceeds 20 MB.") }
        return try validatedImport(data: Data(contentsOf: url), dataset: dataset)
    }

    func validatedImport(data: Data, dataset: BenchmarkDataset) throws -> BenchmarkRun {
        guard data.count <= 20 * 1024 * 1024 else { throw StoreError.invalid("Benchmark file exceeds 20 MB.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var run = try decoder.decode(BenchmarkRun.self, from: data)
        let known = Dictionary(uniqueKeysWithValues: dataset.problems.map { ($0.id, $0) })
        let matchesDataset = run.datasetID == dataset.id
        guard run.schemaVersion == 1, run.status != .running,
              (1...1000).contains(run.datasetCount), run.results.count <= run.datasetCount,
              !matchesDataset || run.datasetCount == dataset.problems.count,
              Set(run.results.map(\.problemID)).count == run.results.count,
              run.promptHash == BenchmarkScorer.promptHash(run.prompt),
              run.prompt.utf8.count <= 65_536, run.model.utf8.count <= 512,
              !run.datasetID.isEmpty, run.datasetID.utf8.count <= 512,
              run.datasetTitle.utf8.count <= 4096, run.evaluatorVersion.utf8.count <= 512,
              run.transportVersion.utf8.count <= 512, run.appVersion.utf8.count <= 512,
              run.startedAt.timeIntervalSince1970.isFinite,
              run.finishedAt != nil, run.finishedAt! >= run.startedAt,
              !run.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError.invalid("Invalid or unsupported benchmark metadata.")
        }
        if run.status == .completed && !run.isComplete { throw StoreError.invalid("Completed run is missing results.") }
        run.results = try run.results.map { item in
            let problem = matchesDataset ? known[item.problemID] : nil
            guard (!matchesDataset || problem != nil), !item.problemID.isEmpty, item.problemID.utf8.count <= 512,
                  item.title.utf8.count <= 4096, item.category.utf8.count <= 512, item.kind.utf8.count <= 512,
                  item.durationSeconds.isFinite, item.durationSeconds >= 0,
                  item.firstTokenSeconds.map({ $0.isFinite && $0 >= 0 && $0 <= item.durationSeconds }) ?? true else {
                throw StoreError.invalid("Invalid benchmark problem or timing.")
            }
            if let usage = item.usage {
                guard [usage.promptTokens, usage.completionTokens, usage.reasoningTokens, usage.cachedTokens]
                    .compactMap({ $0 }).allSatisfy({ $0 >= 0 }) else { throw StoreError.invalid("Invalid token count.") }
                for value in [usage.cost, usage.upstreamCost].compactMap({ $0 }) {
                    guard value.isFinite && value >= 0 else { throw StoreError.invalid("Invalid reported cost.") }
                }
            }
            let score = item.status == .completed && problem != nil && run.evaluatorVersion == BenchmarkScorer.version
                ? try BenchmarkScorer.score(problem: problem!, response: item.response) : nil
            return BenchmarkCaseResult(problemID: item.problemID, title: problem?.title ?? item.title, category: problem?.category ?? item.category,
                kind: problem?.kind ?? item.kind, status: item.status, response: item.response, error: item.error,
                durationSeconds: item.durationSeconds, firstTokenSeconds: item.firstTokenSeconds,
                provider: item.provider, responseModel: item.responseModel, requestID: item.requestID,
                usage: item.usage, score: score)
        }
        return run
    }

    static func comparisonIssue(_ runs: [BenchmarkRun]) -> String? {
        guard runs.count >= 2 else { return "Select at least two saved runs to compare." }
        guard runs.allSatisfy(\.isComplete) else { return "Partial or failed runs cannot be ranked." }
        guard Set(runs.map(\.comparisonKey)).count == 1 else {
            return "Dataset, evaluator, prompt, and transport must match to compare runs."
        }
        guard runs.allSatisfy({ $0.evaluatorVersion == BenchmarkScorer.version }) else {
            return "This evaluator version cannot verify these scores."
        }
        guard runs.allSatisfy({ $0.results.allSatisfy { $0.score != nil } }) else { return "Unverified scores cannot be ranked." }
        return nil
    }

    enum StoreError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }
}
