import Foundation

struct ConfigDocument {
    var root: JSONValue
    let sourceURL: URL?
    /// Original file text for format-preserving saves
    let rawText: String?

    init(root: JSONValue = .object([:]), sourceURL: URL? = nil, rawText: String? = nil) {
        self.root = root
        self.sourceURL = sourceURL
        self.rawText = rawText
    }

    /// Load from URL using JSON5 decoder, preserving raw text
    static func load(from url: URL) throws -> ConfigDocument {
        let data = try Data(contentsOf: url)
        let rawText = String(data: data, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let root = try decoder.decode(JSONValue.self, from: data)
        return ConfigDocument(root: root, sourceURL: url, rawText: rawText)
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(root)
        try data.write(to: url, options: [.atomic])
    }
}
