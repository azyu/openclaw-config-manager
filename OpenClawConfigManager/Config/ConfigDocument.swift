import Foundation

struct ConfigDocument {
    var root: JSONValue
    let sourceURL: URL?

    init(root: JSONValue = .object([:]), sourceURL: URL? = nil) {
        self.root = root
        self.sourceURL = sourceURL
    }

    /// Load from URL using JSON5 decoder
    static func load(from url: URL) throws -> ConfigDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let root = try decoder.decode(JSONValue.self, from: data)
        return ConfigDocument(root: root, sourceURL: url)
    }

    /// Save to URL as standard JSON (JSON5 features stripped on write)
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(root)
        try data.write(to: url, options: [.atomic])
    }
}
