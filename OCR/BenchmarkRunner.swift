import Foundation
import Combine

@MainActor
final class BenchmarkRunner: ObservableObject {
    typealias Transport = @MainActor (Data, String, String, ReasoningEffort, @escaping @MainActor (String) -> Void) async throws -> OCRStreamResult
    @Published private(set) var run: BenchmarkRun?
    @Published private(set) var currentProblem: BenchmarkProblem?
    @Published private(set) var currentResponse = ""
    @Published private(set) var currentStartedAt: Date?
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?
    private var task: Task<Void, Never>?
    private let transport: Transport

    init(transport: @escaping Transport = { data, key, model, effort, delta in
        try await OpenRouterService.streamOCR(imageData: data, apiKey: key, model: model, reasoning: effort, onDelta: delta)
    }) { self.transport = transport }

    func start(dataset: BenchmarkDataset, model: String, reasoning: ReasoningEffort, apiKey: String,
               imageLoader: ((BenchmarkProblem) throws -> Data)? = nil) {
        guard !isRunning else { return }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter an API key in Settings and a model ID before starting."; return
        }
        errorMessage = nil
        let prompt = OpenRouterService.ocrPrompt
        run = BenchmarkRun(id: UUID(), startedAt: Date(), status: .running, model: model,
            reasoning: reasoning, datasetID: dataset.id, datasetTitle: dataset.title,
            datasetCount: dataset.problems.count, evaluatorVersion: BenchmarkScorer.version,
            prompt: prompt, promptHash: BenchmarkScorer.promptHash(prompt),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown", results: [])
        isRunning = true
        task = Task { [self] in
            let clock = ContinuousClock()
            for problem in dataset.problems {
                if Task.isCancelled { break }
                currentProblem = problem; currentResponse = ""; currentStartedAt = Date()
                let started = clock.now
                do {
                    let data = try imageLoader?(problem) ?? Data(contentsOf: dataset.imageURL(for: problem))
                    let response = try await transport(data, apiKey, model, reasoning) { [weak self] delta in
                        self?.currentResponse += delta
                    }
                    try Task.checkCancellation()
                    let duration = seconds(started.duration(to: clock.now))
                    let score = try await Task.detached {
                        try BenchmarkScorer.score(problem: problem, response: response.text)
                    }.value
                    try Task.checkCancellation()
                    run?.results.append(BenchmarkCaseResult(problemID: problem.id, title: problem.title,
                        category: problem.category, kind: problem.kind, status: .completed, response: response.text,
                        error: nil, durationSeconds: duration, firstTokenSeconds: response.firstTokenSeconds,
                        provider: response.provider, responseModel: response.model, requestID: response.requestID,
                        usage: response.usage, score: score))
                } catch {
                    let cancelled = Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
                    let message = cancelled ? "Cancelled by user." : OpenRouterService.redacted(error.localizedDescription, apiKey: apiKey)
                    run?.results.append(BenchmarkCaseResult(problemID: problem.id, title: problem.title,
                        category: problem.category, kind: problem.kind, status: cancelled ? .cancelled : .failed,
                        response: currentResponse.isEmpty ? nil : currentResponse, error: message,
                        durationSeconds: seconds(started.duration(to: clock.now)), firstTokenSeconds: nil,
                        provider: nil, responseModel: nil, requestID: nil, usage: nil, score: nil))
                    run?.status = cancelled ? .cancelled : .failed
                    if !cancelled { errorMessage = message }
                    break
                }
            }
            if run?.status == .running { run?.status = Task.isCancelled ? .cancelled : .completed }
            run?.finishedAt = Date(); isRunning = false; currentStartedAt = nil; task = nil
        }
    }

    func cancel() { task?.cancel() }

    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
