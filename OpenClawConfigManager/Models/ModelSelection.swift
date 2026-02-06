import Foundation

struct ModelSelection: Equatable {
    var primary: String
    var fallbacks: [String]

    // Normalization: trim whitespace, remove empty, dedupe fallbacks, remove fallbacks == primary
    func normalized() -> ModelSelection {
        let normalizedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines)

        var seen = Set<String>()
        seen.insert(normalizedPrimary)

        let normalizedFallbacks = fallbacks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != normalizedPrimary }
            .filter { seen.insert($0).inserted }

        return ModelSelection(primary: normalizedPrimary, fallbacks: normalizedFallbacks)
    }

    // Check if a model ID is known
    static func isKnown(_ modelId: String) -> Bool {
        ModelCatalog.find(by: modelId) != nil
    }
}
