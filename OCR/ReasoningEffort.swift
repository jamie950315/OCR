import Foundation

nonisolated enum ReasoningEffort: String, CaseIterable, Codable, Identifiable, Sendable {
    case modelDefault = "default", off, minimal, low, medium, high
    var id: String { rawValue }
    var displayName: String { self == .modelDefault ? "Model default" : rawValue.capitalized }
    var requestValue: [String: Any]? {
        switch self {
        case .modelDefault: nil
        case .off: ["enabled": false]
        default: ["effort": rawValue]
        }
    }
}

nonisolated struct OCRUsage: Codable, Sendable {
    var promptTokens: Int?
    var completionTokens: Int?
    var reasoningTokens: Int?
    var cachedTokens: Int?
    var cost: Double?
    var upstreamCost: Double?
    var isBYOK: Bool?

    init(promptTokens: Int? = nil, completionTokens: Int? = nil, reasoningTokens: Int? = nil,
         cachedTokens: Int? = nil, cost: Double? = nil, upstreamCost: Double? = nil, isBYOK: Bool? = nil) {
        self.promptTokens = promptTokens; self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens; self.cachedTokens = cachedTokens
        self.cost = cost; self.upstreamCost = upstreamCost; self.isBYOK = isBYOK
    }

    init(json: [String: Any]) {
        promptTokens = json["prompt_tokens"] as? Int
        completionTokens = json["completion_tokens"] as? Int
        reasoningTokens = (json["completion_tokens_details"] as? [String: Any])?["reasoning_tokens"] as? Int
        cachedTokens = (json["prompt_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
        cost = json["cost"] as? Double
        upstreamCost = (json["cost_details"] as? [String: Any])?["upstream_inference_cost"] as? Double
        isBYOK = json["is_byok"] as? Bool
    }
}

nonisolated struct OCRStreamResult: Sendable {
    var text: String?
    var model: String?
    var provider: String?
    var requestID: String?
    var usage: OCRUsage?
    var firstTokenSeconds: Double?
}
