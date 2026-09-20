import Foundation
import CryptoKit
import JavaScriptCore

/// Pure local evaluation. Call from the benchmark worker, not while rendering UI.
/// Every table evaluation owns its JavaScript VM; no JSValue crosses threads.
nonisolated enum BenchmarkScorer {
    static let version = "ocr50-rendered-markdown-v1"

    static func promptHash(_ prompt: String) -> String {
        SHA256.hash(data: Data(prompt.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func score(problem: BenchmarkProblem, response: String?) throws -> BenchmarkScore {
        try score(problem: problem, response: response, bundle: .main)
    }

    static func score(problem: BenchmarkProblem, response: String?, bundle: Bundle) throws -> BenchmarkScore {
        let expected: String
        let actual: String
        var notes: [String] = []
        var passed = false
        if problem.kind == "plain" {
            expected = normalizePlain(problem.expectedText ?? "", mode: problem.whitespace ?? "lines")
            actual = normalizePlain(response ?? "", mode: problem.whitespace ?? "lines")
            passed = response != nil && expected == actual
            if !passed { notes.append("Text, punctuation, line order, or whitespace differs from the expected transcription.") }
        } else {
            let tables = problem.tables ?? []
            let gaps = (problem.proseGaps ?? []).map(normalizeProse)
            expected = semanticText(tables: tables, gaps: gaps)
            if let response {
                guard response.utf8.count <= 131_072 else { throw BenchmarkDataError.responseTooLarge }
                let parsed = try parseMarkdown(response, bundle: bundle)
                let actualGaps = parsed.gaps.map(normalizeProse)
                actual = semanticText(tables: parsed.tables, gaps: actualGaps)
                notes = parsed.errors
                if parsed.tableCount != tables.count { notes.append("Expected \(tables.count) Markdown tables; found \(parsed.tableCount).") }
                if parsed.tables != tables { notes.append("Table cells, rows, columns, or table order differ from the expected result.") }
                if actualGaps != gaps { notes.append("Text before, between, or after the tables differs from the expected result.") }
                passed = notes.isEmpty
            } else { actual = "" }
        }
        if response == nil { notes.append("The API returned null content; a string is required, including for an image without text.") }
        guard expected.unicodeScalars.count <= 16_384, actual.unicodeScalars.count <= 131_072 else {
            throw BenchmarkDataError.responseTooLarge
        }
        return BenchmarkScore(passed: passed, characterEdits: try distance(expected, actual),
                              expectedCharacters: expected.unicodeScalars.count, notes: notes)
    }

    private struct ParsedMarkdown: Decodable {
        let tables: [[[String]]]
        let gaps: [String]
        let tableCount: Int
        let errors: [String]
    }

    private static func parseMarkdown(_ source: String, bundle: Bundle) throws -> ParsedMarkdown {
        guard let vm = JSVirtualMachine(), let context = JSContext(virtualMachine: vm) else {
            throw BenchmarkDataError.parserFailure
        }
        for name in ["markdown-it-14.1.0.min.js", "evaluate-markdown.js"] {
            let url = try BenchmarkDataset.resourceURL(name, bundle: bundle)
            let trustedScript = try String(contentsOf: url, encoding: .utf8)
            context.evaluateScript(trustedScript, withSourceURL: url)
            guard context.exception == nil else { throw BenchmarkDataError.parserFailure }
        }
        // Never interpolate response text into evaluated source code.
        guard let function = context.objectForKeyedSubscript("extractBenchmarkMarkdown"),
              let result = function.call(withArguments: [source]), context.exception == nil,
              let json = result.toString()?.data(using: .utf8) else { throw BenchmarkDataError.parserFailure }
        return try JSONDecoder().decode(ParsedMarkdown.self, from: json)
    }

    private static func normalizePlain(_ text: String, mode: String) -> String {
        var text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if text.hasSuffix("\n") { text.removeLast() }
        if mode == "lines" {
            return text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n")
        }
        return text
    }

    private static func normalizeProse(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func semanticText(tables: [[[String]]], gaps: [String]) -> String {
        var chunks: [String] = []
        for (index, table) in tables.enumerated() {
            chunks.append(index < gaps.count ? gaps[index] : "")
            chunks.append(table.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
        }
        if gaps.count > tables.count { chunks.append(contentsOf: gaps.dropFirst(tables.count)) }
        return chunks.joined(separator: "\n")
    }

    private static func distance(_ lhs: String, _ rhs: String) throws -> Int {
        if lhs == rhs { return 0 }
        let a = Array(lhs.unicodeScalars), b = Array(rhs.unicodeScalars)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        // Bounded quadratic work: malformed output must not freeze the application.
        guard a.count * b.count <= 16_000_000 else { throw BenchmarkDataError.responseTooLarge }
        var previous = Array(0...b.count)
        for (i, character) in a.enumerated() {
            var current = [i + 1]
            current.reserveCapacity(b.count + 1)
            for (j, other) in b.enumerated() {
                current.append(min(current[j] + 1, previous[j + 1] + 1, previous[j] + (character == other ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }
}
