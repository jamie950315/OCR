import Foundation

nonisolated enum BenchmarkDataError: LocalizedError {
    case missingResource(String)
    case invalidManifest
    case responseTooLarge
    case parserFailure

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Missing benchmark resource: \(name)"
        case .invalidManifest: return "The bundled benchmark manifest is invalid."
        case .responseTooLarge: return "The model response exceeds the benchmark evaluator's safety limits."
        case .parserFailure: return "The bundled Markdown evaluator could not parse the response."
        }
    }
}

extension BenchmarkDataset {
    static func load(bundle: Bundle = .main) throws -> BenchmarkDataset {
        let url = try resourceURL("manifest.json", bundle: bundle)
        let dataset = try JSONDecoder().decode(BenchmarkDataset.self, from: Data(contentsOf: url))
        guard dataset.problems.count == 50,
              Set(dataset.problems.map(\.id)).count == dataset.problems.count,
              !dataset.id.isEmpty else { throw BenchmarkDataError.invalidManifest }
        for problem in dataset.problems {
            guard ["plain", "table"].contains(problem.kind),
                  !problem.id.isEmpty, !problem.title.isEmpty,
                  problem.kind == "plain" ? problem.expectedText != nil :
                    (problem.tables != nil && problem.proseGaps?.count == (problem.tables?.count ?? 0) + 1)
            else { throw BenchmarkDataError.invalidManifest }
            _ = try dataset.imageURL(for: problem, bundle: bundle)
        }
        return dataset
    }

    func imageURL(for problem: BenchmarkProblem, bundle: Bundle = .main) throws -> URL {
        guard problem.imageName == (problem.imageName as NSString).lastPathComponent,
              problem.imageName.hasSuffix(".png") else { throw BenchmarkDataError.invalidManifest }
        return try Self.resourceURL(problem.imageName, bundle: bundle)
    }

    nonisolated static func resourceURL(_ name: String, bundle: Bundle) throws -> URL {
        guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "BenchmarkAssets") else {
            throw BenchmarkDataError.missingResource(name)
        }
        return url
    }
}
