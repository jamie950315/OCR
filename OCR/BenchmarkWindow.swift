import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
private final class BenchmarkConfiguration: ObservableObject {
    @Published var model = ""
    @Published var reasoning: ReasoningEffort = .low
}

@MainActor
final class BenchmarkWindowController: NSWindowController, NSWindowDelegate {
    static let shared = BenchmarkWindowController()
    let runner = BenchmarkRunner()
    private let configuration = BenchmarkConfiguration()
    private var runningSubscription: AnyCancellable?
    private init() {
        super.init(window: nil)
        runningSubscription = runner.$isRunning.sink { running in AppState.shared.isBenchmarkRunning = running }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(model: String, reasoning: ReasoningEffort) {
        if !runner.isRunning { configuration.model = model; configuration.reasoning = reasoning }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OCR Model Benchmark"; window.minSize = NSSize(width: 900, height: 650)
            window.isReleasedWhenClosed = false; window.delegate = self
            let content = NSHostingView(rootView: BenchmarkWindowView(runner: runner, configuration: configuration))
            content.sizingOptions = []
            window.contentView = content
            window.setContentSize(NSSize(width: 1120, height: 780))
            self.window = window; window.center()
        }
        NSApp.activate(ignoringOtherApps: true); showWindow(nil); window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard runner.isRunning else { return true }
        let alert = NSAlert(); alert.messageText = "Cancel the running benchmark?"
        alert.informativeText = "Closing stops the current request and all remaining problems. Completed results stay available when you reopen this window. Charges already incurred may still apply."
        alert.addButton(withTitle: "Keep Running"); alert.addButton(withTitle: "Cancel and Close")
        guard alert.runModal() == .alertSecondButtonReturn else { return false }
        runner.cancel(); return true
    }
}

private struct BenchmarkWindowView: View {
    @ObservedObject var runner: BenchmarkRunner
    @ObservedObject var configuration: BenchmarkConfiguration
    @State private var dataset: BenchmarkDataset?
    @State private var saved: [BenchmarkRun] = []
    @State private var selectedRuns: Set<UUID> = []
    @State private var selectedResult: String?
    @State private var followingStream = true
    @State private var message: String?
    @State private var activeTab = "Run"
    @State private var historyBusy = false
    private let store = BenchmarkStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OCR Model Benchmark").font(.title2.bold())
                Spacer()
                Picker("Page", selection: $activeTab) {
                    Text("Run & Results").tag("Run"); Text("Saved & Compare").tag("Saved")
                }.pickerStyle(.segmented).labelsHidden().frame(width: 290)
            }
            if let message { Text(message).foregroundStyle(.orange).textSelection(.enabled) }
            if let error = runner.errorMessage { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            if activeTab == "Saved" { history } else { runPage }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { do { dataset = try BenchmarkDataset.load(); await reload() } catch { message = error.localizedDescription } }
    }

    private var runPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("OpenRouter model ID", text: $configuration.model).textFieldStyle(.roundedBorder)
                Picker("Reasoning", selection: $configuration.reasoning) {
                    ForEach(ReasoningEffort.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.frame(width: 230)
            }.disabled(runner.isRunning)
            Text("Runs all 50 bundled synthetic images through your OpenRouter account. Images and the OCR prompt are sent to the selected provider; API charges apply. No screen captures or API keys are saved. Model and reasoning apply only to this benchmark.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if runner.isRunning {
                    Button("Cancel Benchmark", role: .destructive) { runner.cancel() }
                } else {
                    Button("Start 50-Problem Benchmark") { start() }.buttonStyle(.borderedProminent)
                        .disabled(dataset == nil || configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let run = runner.run, !runner.isRunning {
                    Button(saved.contains(where: { $0.id == run.id }) ? "Run Saved" : "Save Run") { save(run) }
                        .disabled(saved.contains(where: { $0.id == run.id }))
                    Button("Export JSON…") { export(run) }
                }
                Spacer()
                if let run = runner.run { Text("Processed \(run.processedCount)/\(run.datasetCount) · \(Int(Double(run.processedCount) / Double(max(1, run.datasetCount)) * 100))%") .monospacedDigit() }
            }
            if let run = runner.run {
                ProgressView(value: Double(run.processedCount), total: Double(run.datasetCount))
                if !runner.isRunning { summary(run) }
            }
            if runner.isRunning, let problem = runner.currentProblem {
                HStack {
                    Text("\((runner.run?.results.count ?? 0) + 1)/\(dataset?.problems.count ?? 50) · \(problem.title) · \(problem.category)").font(.headline)
                    Spacer()
                    if let started = runner.currentStartedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(String(format: "Current problem: %.0fs", context.date.timeIntervalSince(started))).monospacedDigit()
                        }
                    }
                    Toggle("Follow stream", isOn: $followingStream).toggleStyle(.checkbox)
                }
                problemContent(problem, response: runner.currentResponse, live: true)
            } else if let run = runner.run, !run.results.isEmpty {
                resultReview(run)
            } else if let problem = dataset?.problems.first {
                Text("Preview · \(problem.title)").font(.headline)
                problemContent(problem, response: "The model response will appear here in real time after you start.", live: false)
            }
        }
    }

    private func summary(_ run: BenchmarkRun) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(run.model) · \(run.reasoning.displayName)").font(.subheadline.bold())
            Text(scoreLabel(run)).font(.headline)
            HStack(spacing: 20) {
                Text("Median: \(run.medianSeconds.map { String(format: "%.2fs", $0) } ?? "—")")
                Text("Reported cost: \(run.reportedCost.map { String(format: "$%.6f", $0) } ?? "Unavailable")")
                if hasVerifiedScores(run) { ForEach(["plain", "table"], id: \.self) { kind in
                    let items = run.results.filter { $0.status != .cancelled && (kind == "plain" ? $0.kind == "plain" : $0.kind != "plain") }
                    Text("\(kind == "plain" ? "Plain text" : "Table / mixed"): \(items.filter { $0.score?.passed == true }.count)/\(items.count)")
                } }
            }.font(.callout)
            Text("Strict synthetic-sample scores are not a general accuracy rate. Timing includes network and streaming; reported costs can be incomplete and affected by caching. Partial runs cannot be ranked.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func problemContent(_ problem: BenchmarkProblem, response: String, live: Bool) -> some View {
        HSplitView {
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    if let url = try? dataset?.imageURL(for: problem), let image = NSImage(contentsOf: url) {
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(width: max(1, geometry.size.width - 16)).padding(.horizontal, 8)
                    } else { Text("Bundled image unavailable.") }
                }
            }.frame(minWidth: 300)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(response.isEmpty ? (live ? "Waiting for response…" : "(Empty response)") : response)
                            .font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        Color.clear.frame(height: 1).id("end")
                    }.padding(10)
                }
                .onChange(of: response) { _, _ in if live && followingStream { proxy.scrollTo("end", anchor: .bottom) } }
            }.frame(minWidth: 300)
        }.frame(minHeight: 260, maxHeight: .infinity).background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private func resultReview(_ run: BenchmarkRun) -> some View {
        VStack(alignment: .leading) {
            Picker("Review problem", selection: $selectedResult) {
                Text("Select a problem").tag(String?.none)
                ForEach(run.results) { result in
                    Text("\(result.status == .cancelled ? "CANCELLED" : result.status == .failed ? "ERROR" : result.score.map { $0.passed ? "PASS" : "FAIL" } ?? "UNVERIFIED") · \(result.title)").tag(Optional(result.problemID))
                }
            }
            if let result = run.results.first(where: { $0.problemID == selectedResult }) {
                Text("\(String(format: "%.2fs", result.durationSeconds)) · Provider: \(result.provider ?? "Not reported") · Model: \(result.responseModel ?? run.model)")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Text((result.score?.notes ?? [result.error ?? "No score"]).joined(separator: " · "))
                    .font(.caption).textSelection(.enabled)
                if run.datasetID == dataset?.id, let problem = dataset?.problems.first(where: { $0.id == result.problemID }) {
                    problemContent(problem, response: result.response ?? "(No textual response)", live: false)
                } else {
                    Text("Source image is not bundled for this dataset. Scores are unverified.").foregroundStyle(.secondary)
                    ScrollView { Text(result.response ?? "(No textual response)").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                }
            } else { Text("Select a result to inspect the source image, response, and scoring notes.").foregroundStyle(.secondary); Spacer() }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Button("Import JSON…") { importRun() }; Button("Refresh") { Task { await reload() } }; Spacer(); if historyBusy { ProgressView().controlSize(.small); Text("Verifying saved results…") } }.disabled(historyBusy)
            List(saved, selection: $selectedRuns) { run in
                HStack {
                    Toggle("Compare \(run.model) \(run.reasoning.displayName)", isOn: Binding(
                        get: { selectedRuns.contains(run.id) },
                        set: { included in
                            if included { selectedRuns.insert(run.id) } else { selectedRuns.remove(run.id) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help("Include this run in the comparison")
                    VStack(alignment: .leading) {
                        Text("\(run.model) · \(run.reasoning.displayName)").font(.headline)
                        Text("\(run.startedAt.formatted()) · \(scoreLabel(run))").font(.caption)
                    }
                    Spacer(); Button("Export…") { export(run) }
                }.tag(run.id)
            }.frame(minHeight: 170)
            Text("Select checkboxes to compare runs. Click a row to inspect it. Imported results are locally rescored; model, timing, and billing metadata remain self-reported.").font(.caption).foregroundStyle(.secondary)
            let chosen = saved.filter { selectedRuns.contains($0.id) }
            if let issue = BenchmarkStore.comparisonIssue(chosen) { Text(issue).foregroundStyle(.secondary) }
            else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(chosen) { summary($0) }
                    }
                }
            }
            if chosen.count == 1, let run = chosen.first { resultReview(run) }
        }
    }

    private func start() {
        guard let dataset else { return }
        guard !AppState.shared.isCaptureActive else { message = "Wait for screen capture or OCR to finish before benchmarking."; return }
        if let run = runner.run, !saved.contains(where: { $0.id == run.id }) {
            let alert = NSAlert(); alert.messageText = "Start a new run without saving?"
            alert.informativeText = "The current unsaved results will be replaced. Use Save Run first if you want to compare them later."
            alert.addButton(withTitle: "Keep Results"); alert.addButton(withTitle: "Start New Run")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        message = nil; selectedResult = nil
        runner.start(dataset: dataset, model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines), reasoning: configuration.reasoning, apiKey: AppState.shared.apiKey)
    }
    private func hasVerifiedScores(_ run: BenchmarkRun) -> Bool {
        run.datasetID == dataset?.id && run.evaluatorVersion == BenchmarkScorer.version && run.results.filter { $0.status == .completed }.allSatisfy { $0.score != nil }
    }
    private func scoreLabel(_ run: BenchmarkRun) -> String {
        guard hasVerifiedScores(run) else { return "\(run.status.rawValue.capitalized) · Scores unavailable / unverified" }
        return run.isComplete ? "Completed · \(run.passedCount)/\(run.datasetCount) fully correct" : "\(run.status.rawValue.capitalized) · \(run.passedCount) passed of \(run.processedCount) processed · \(run.datasetCount) planned"
    }
    private func reload() async {
        guard let dataset, !historyBusy else { return }
        historyBusy = true; defer { historyBusy = false }
        do {
            let result = try await Task.detached { try store.loadWithWarnings(dataset: dataset) }.value
            saved = result.runs
            if !result.warnings.isEmpty { message = "Some saved files could not be loaded: " + result.warnings.joined(separator: " · ") }
        } catch { message = error.localizedDescription }
    }
    private func save(_ run: BenchmarkRun) {
        Task { do { try await Task.detached { try store.save(run) }.value; message = "Run saved locally."; await reload() } catch { message = error.localizedDescription } }
    }
    private func export(_ run: BenchmarkRun) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "ocr-benchmark-\(run.id).json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try BenchmarkStore.encode(run).write(to: url, options: .atomic); message = "Benchmark exported." } catch { message = error.localizedDescription }
        }
    }
    private func importRun() {
        guard let dataset else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task {
              historyBusy = true
              let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() }; historyBusy = false }
              do {
                let run = try await Task.detached { try store.validatedImport(url: url, dataset: dataset) }.value
                guard !saved.contains(where: { $0.id == run.id }) else { message = "This run is already saved."; return }
                try await Task.detached { try store.save(run) }.value
                saved.append(run); saved.sort { $0.startedAt > $1.startedAt }
                message = hasVerifiedScores(run) ? "Imported and verified benchmark." : "Imported benchmark for inspection; scores are unavailable / unverified."
              } catch { message = error.localizedDescription }
            }
        }
    }
}
