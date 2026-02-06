import Foundation

enum ConfigFileManager {
    /// Default config path: ~/.openclaw/openclaw.json
    /// Override via OPENCLAW_CONFIG_PATH env var (for testing)
    static var configURL: URL {
        if let override = ProcessInfo.processInfo.environment["OPENCLAW_CONFIG_PATH"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("openclaw.json")
    }

    /// Load config from disk
    /// - Returns empty document if file doesn't exist
    /// - Throws on parse error
    static func load() throws -> ConfigDocument {
        let fileURL = configURL
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return ConfigDocument()
        }
        return try ConfigDocument.load(from: fileURL)
    }

    static func save(_ document: ConfigDocument) throws {
        let fileURL = configURL
        let directoryURL = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try createBackup()
        }

        let outputData: Data
        
        if let rawText = document.rawText {
            let (selection, _) = ConfigModelAccess.readModelSelection(from: document.root)
            var patched = try JSON5TextPatcher.patchPrimary(in: rawText, newValue: selection.primary)
            patched = try JSON5TextPatcher.patchFallbacks(in: patched, newValues: selection.fallbacks)
            outputData = patched.data(using: .utf8) ?? Data()
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            outputData = try encoder.encode(document.root)
        }

        let tempURL = directoryURL.appendingPathComponent(
            "\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)"
        )
        try outputData.write(to: tempURL)

        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: fileURL)
        }
    }

    /// Create backup of existing file
    /// Returns backup URL or nil if no existing file
    static func createBackup() throws -> URL? {
        let fileURL = configURL
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())

        var backupName = "\(fileURL.lastPathComponent).bak-\(timestamp)"
        var backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(backupName)

        if fileManager.fileExists(atPath: backupURL.path) {
            backupName = "\(fileURL.lastPathComponent).bak-\(timestamp)-\(UUID().uuidString.prefix(8))"
            backupURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent(backupName)
        }

        try fileManager.copyItem(at: fileURL, to: backupURL)
        return backupURL
    }
}
