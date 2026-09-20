import Foundation
import Testing
@testable import OCR

@MainActor
struct BenchmarkScorerTests {
    private func plain(_ text: String, whitespace: String = "exact") -> BenchmarkProblem {
        BenchmarkProblem(id: "test", title: "Test", category: "Text", kind: "plain",
                         imageName: "test.png", expectedText: text, whitespace: whitespace, tables: nil, proseGaps: nil)
    }

    private func table() -> BenchmarkProblem {
        BenchmarkProblem(id: "test", title: "Test", category: "Tables", kind: "table",
                         imageName: "test.png", expectedText: nil, whitespace: nil,
                         tables: [[["Header", "Value"], ["*literal*", "A\nB"], ["pipe | slash \\" , ""]]],
                         proseGaps: ["Before", "After"])
    }

    private func escaped(_ text: String) -> String {
        let html = text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        let punctuation = Set("\\`*_{}[]()#+.!|~-")
        return html.map { punctuation.contains($0) ? "\\" + String($0) : String($0) }
            .joined().replacingOccurrences(of: "\n", with: "<br>")
    }

    private func golden(_ problem: BenchmarkProblem) -> String {
        if problem.kind == "plain" { return problem.expectedText ?? "" }
        var chunks: [String] = []
        let tables = problem.tables ?? []
        let gaps = problem.proseGaps ?? []
        for (i, table) in tables.enumerated() {
            if !gaps[i].isEmpty { chunks.append(escaped(gaps[i])) }
            var lines = table.map { "| " + $0.map(escaped).joined(separator: " | ") + " |" }
            lines.insert("| " + Array(repeating: "---", count: table[0].count).joined(separator: " | ") + " |", at: 1)
            chunks.append(lines.joined(separator: "\n"))
        }
        if let last = gaps.last, !last.isEmpty { chunks.append(escaped(last)) }
        return chunks.joined(separator: "\n\n")
    }

    @Test func allFiftyBundledGoldenResponsesPass() throws {
        let dataset = try BenchmarkDataset.load()
        #expect(dataset.problems.count == 50)
        for problem in dataset.problems {
            #expect(FileManager.default.fileExists(atPath: try dataset.imageURL(for: problem).path))
            let result = try BenchmarkScorer.score(problem: problem, response: golden(problem))
            #expect(result.passed, "Golden response failed: \(problem.id)")
            #expect(result.characterEdits == 0)
        }
    }

    @Test func nullDoesNotPassEmptyImageContract() throws {
        #expect(try !BenchmarkScorer.score(problem: plain(""), response: nil).passed)
        #expect(try BenchmarkScorer.score(problem: plain(""), response: "").passed)
    }

    @Test func plainTextPreservesIndentationAndOneTransportNewline() throws {
        let problem = plain("def f():\n    return 1")
        #expect(try BenchmarkScorer.score(problem: problem, response: "def f():\r\n    return 1\r\n").passed)
        for bad in ["def f():\nreturn 1", "def f():\n    return 1\n\n", "```\ndef f():\n    return 1\n```", "    return 1\ndef f():"] {
            #expect(try !BenchmarkScorer.score(problem: problem, response: bad).passed)
        }
        #expect(try BenchmarkScorer.score(problem: plain("A\nB", whitespace: "lines"), response: "  A  \n B ").passed)
    }

    @Test func literalSymbolsAndCodeSpansAreRendered() throws {
        let problem = table()
        let output = golden(problem)
        #expect(try BenchmarkScorer.score(problem: problem, response: output).passed)
        #expect(try BenchmarkScorer.score(problem: problem, response: output.replacingOccurrences(of: "\\*literal\\*", with: "`*literal*`")).passed)
        #expect(try !BenchmarkScorer.score(problem: problem, response: output.replacingOccurrences(of: "\\*literal\\*", with: "*literal*")).passed)
        #expect(try !BenchmarkScorer.score(problem: problem, response: output.replacingOccurrences(of: "<br>", with: " ")).passed)
    }

    @Test func tablesRejectFencesHTMLAndWrongProsePlacement() throws {
        let problem = table(), output = golden(table())
        for bad in ["```markdown\n" + output + "\n```", "<table><tr><td>Header</td></tr></table>",
                    output + "\n\n<script>throw new Error('never executed')</script>",
                    output.replacingOccurrences(of: "Before", with: "After"),
                    output.replacingOccurrences(of: "After", with: ""),
                    output + "\n\n| Extra |\n| --- |\n| table |"] {
            #expect(try !BenchmarkScorer.score(problem: problem, response: bad).passed)
        }
    }

    @Test func modelTextCannotExecuteJavaScript() throws {
        let problem = table()
        let hostile = "'); throw new Error('injected'); //\u{0}\u{2028}"
        let result = try BenchmarkScorer.score(problem: problem, response: hostile)
        #expect(!result.passed)
        #expect(result.notes.contains { $0.contains("Markdown tables") })
    }

    @Test func characterDistanceCountsUnicodeScalarsAndPreservesPunctuation() throws {
        let score = try BenchmarkScorer.score(problem: plain("A – B"), response: "A - B")
        #expect(!score.passed)
        #expect(score.characterEdits == 1)
        #expect(score.expectedCharacters == 5)
        #expect(BenchmarkScorer.promptHash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
