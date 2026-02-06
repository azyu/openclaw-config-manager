import Foundation
#if canImport(XCTest)
import XCTest
@testable import OpenClawConfigManager

final class ConfigFileManagerTests: XCTestCase {
    func testLoadReturnsEmptyDocumentWhenMissing() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let configURL = tempDirectory.appendingPathComponent("openclaw.json")

        try withConfigPath(configURL) {
            let document = try ConfigFileManager.load()
            XCTAssertEqual(document.root, .object([:]))
            XCTAssertNil(document.sourceURL)
        }
    }

    func testSaveCreatesDirectoryWhenMissing() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let configURL = tempDirectory
            .appendingPathComponent("nested")
            .appendingPathComponent("openclaw.json")

        try withConfigPath(configURL) {
            let document = ConfigDocument(root: .object(["name": .string("test")]))
            try ConfigFileManager.save(document)

            XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.deletingLastPathComponent().path))
        }
    }

    func testSaveCreatesBackupWhenFileExists() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let configURL = tempDirectory.appendingPathComponent("openclaw.json")
        let oldDocument = ConfigDocument(root: .object(["version": .number(1)]))
        let newDocument = ConfigDocument(root: .object(["version": .number(2)]))

        let encoder = JSONEncoder()
        let oldData = try encoder.encode(oldDocument.root)
        try oldData.write(to: configURL)

        try withConfigPath(configURL) {
            try ConfigFileManager.save(newDocument)
        }

        let directoryContents = try FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )
        let backupPrefix = "\(configURL.lastPathComponent).bak-"
        let backups = directoryContents.filter { $0.lastPathComponent.hasPrefix(backupPrefix) }
        XCTAssertEqual(backups.count, 1)

        let backupData = try Data(contentsOf: backups[0])
        XCTAssertEqual(backupData, oldData)
    }

    func testSaveUsesAtomicReplacement() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let configURL = tempDirectory.appendingPathComponent("openclaw.json")
        let oldDocument = ConfigDocument(root: .object(["value": .string("old")]))
        let newDocument = ConfigDocument(root: .object(["value": .string("new")]))

        let encoder = JSONEncoder()
        let oldData = try encoder.encode(oldDocument.root)
        try oldData.write(to: configURL)

        let fileHandle = try FileHandle(forReadingFrom: configURL)
        defer { try? fileHandle.close() }

        try withConfigPath(configURL) {
            try ConfigFileManager.save(newDocument)
        }

        let handleData = try fileHandle.readToEnd() ?? Data()
        XCTAssertEqual(handleData, oldData)

        let newData = try Data(contentsOf: configURL)
        let expectedEncoder = JSONEncoder()
        expectedEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let expectedNewData = try expectedEncoder.encode(newDocument.root)
        XCTAssertEqual(newData, expectedNewData)
    }

    func testConfigPathOverride() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let configURL = tempDirectory.appendingPathComponent("openclaw.json")

        withConfigPath(configURL) {
            XCTAssertEqual(ConfigFileManager.configURL.path, configURL.path)
        }
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let baseURL = FileManager.default.temporaryDirectory
    let tempDirectory = baseURL.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    return tempDirectory
}

private func withConfigPath(_ url: URL, _ block: () throws -> Void) rethrows {
    let path = url.path
    setenv("OPENCLAW_CONFIG_PATH", path, 1)
    defer { unsetenv("OPENCLAW_CONFIG_PATH") }
    try block()
}
#endif
