import Foundation

enum ConfigModelAccess {
    private static let defaultWarning = "Missing or malformed agents.defaults.model"

    /// Extract ModelSelection from config document
    /// - String form: "provider/model" -> primary only, empty fallbacks
    /// - Object form: { primary: "...", fallbacks: [...] }
    /// - Missing/malformed: returns default with warning
    static func readModelSelection(from root: JSONValue) -> (ModelSelection, warning: String?) {
        let defaultSelection = ModelSelection(primary: "", fallbacks: [])

        guard let modelValue = root["agents"]?["defaults"]?["model"] else {
            return (defaultSelection, defaultWarning)
        }

        switch modelValue {
        case let .string(value):
            return (ModelSelection(primary: value, fallbacks: []), nil)
        case let .object(object):
            guard let primary = object["primary"]?.stringValue else {
                return (defaultSelection, defaultWarning)
            }

            let fallbacks = object["fallbacks"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            return (ModelSelection(primary: primary, fallbacks: fallbacks), nil)
        case .null:
            return (defaultSelection, defaultWarning)
        default:
            return (defaultSelection, defaultWarning)
        }
    }

    /// Update model selection in config, preserving all other keys
    /// Creates agents.defaults path if missing
    static func writeModelSelection(_ selection: ModelSelection, to root: inout JSONValue) {
        var rootObject = root.objectValue ?? [:]
        var agentsObject = rootObject["agents"]?.objectValue ?? [:]
        var defaultsObject = agentsObject["defaults"]?.objectValue ?? [:]

        defaultsObject["model"] = .object([
            "primary": .string(selection.primary),
            "fallbacks": .array(selection.fallbacks.map { .string($0) })
        ])

        agentsObject["defaults"] = .object(defaultsObject)
        rootObject["agents"] = .object(agentsObject)
        root = .object(rootObject)
    }
}
