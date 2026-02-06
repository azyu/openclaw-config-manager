import Foundation

#if canImport(XCTest)
import XCTest

@testable import OpenClawConfigManager

final class ConfigModelAccessTests: XCTestCase {
    private func decodeJSON5(_ string: String) throws -> JSONValue {
        let data = Data(string.utf8)
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return try decoder.decode(JSONValue.self, from: data)
    }

    func testReadingStringFormModel() throws {
        let json5 = #"""
        {
          agents: { defaults: { model: "openai/gpt-4o" } }
        }
        """#

        let root = try decodeJSON5(json5)
        let (selection, warning) = ConfigModelAccess.readModelSelection(from: root)

        XCTAssertEqual(selection, ModelSelection(primary: "openai/gpt-4o", fallbacks: []))
        XCTAssertNil(warning)
    }

    func testReadingObjectFormModel() throws {
        let json5 = #"""
        {
          agents: {
            defaults: {
              model: { primary: "anthropic/claude-sonnet-4", fallbacks: ["openai/gpt-4o"] }
            }
          }
        }
        """#

        let root = try decodeJSON5(json5)
        let (selection, warning) = ConfigModelAccess.readModelSelection(from: root)

        XCTAssertEqual(selection, ModelSelection(primary: "anthropic/claude-sonnet-4", fallbacks: ["openai/gpt-4o"]))
        XCTAssertNil(warning)
    }

    func testReadingMissingModelReturnsDefault() throws {
        let json5 = #"""
        {
          agents: { defaults: { } }
        }
        """#

        let root = try decodeJSON5(json5)
        let (selection, warning) = ConfigModelAccess.readModelSelection(from: root)

        XCTAssertEqual(selection, ModelSelection(primary: "", fallbacks: []))
        XCTAssertNotNil(warning)
    }

    func testWritingPreservesUnrelatedKeysAtRootLevel() throws {
        let json5 = #"""
        {
          gateway: { port: 18789 },
          agents: { defaults: { model: "openai/gpt-4o" } }
        }
        """#

        var root = try decodeJSON5(json5)
        ConfigModelAccess.writeModelSelection(
            ModelSelection(primary: "anthropic/claude-sonnet-4", fallbacks: []),
            to: &root
        )

        XCTAssertEqual(root["gateway"]?["port"], .number(18789))
    }

    func testWritingPreservesUnrelatedKeysInsideAgents() throws {
        let json5 = #"""
        {
          agents: {
            list: ["alpha", "beta"],
            defaults: { model: "openai/gpt-4o" }
          }
        }
        """#

        var root = try decodeJSON5(json5)
        ConfigModelAccess.writeModelSelection(
            ModelSelection(primary: "anthropic/claude-sonnet-4", fallbacks: []),
            to: &root
        )

        let list = root["agents"]?["list"]?.arrayValue?.compactMap { $0.stringValue }
        XCTAssertEqual(list, ["alpha", "beta"])
    }

    func testWritingPreservesUnrelatedKeysInsideAgentsDefaults() throws {
        let json5 = #"""
        {
          agents: {
            defaults: { workspace: "~/workspace" }
          }
        }
        """#

        var root = try decodeJSON5(json5)
        ConfigModelAccess.writeModelSelection(
            ModelSelection(primary: "openai/gpt-4o", fallbacks: []),
            to: &root
        )

        XCTAssertEqual(root["agents"]?["defaults"]?["workspace"]?.stringValue, "~/workspace")
    }

    func testWritingCreatesPathWhenMissing() {
        var root = JSONValue.object([:])

        ConfigModelAccess.writeModelSelection(
            ModelSelection(primary: "openai/gpt-4o", fallbacks: ["anthropic/claude-sonnet-4"]),
            to: &root
        )

        let modelObject = root["agents"]?["defaults"]?["model"]?.objectValue
        XCTAssertEqual(modelObject?["primary"]?.stringValue, "openai/gpt-4o")
        XCTAssertEqual(
            modelObject?["fallbacks"]?.arrayValue?.compactMap { $0.stringValue },
            ["anthropic/claude-sonnet-4"]
        )
    }

    func testRoundTripReadModifyWriteRead() throws {
        let json5 = #"""
        {
          agents: {
            defaults: { model: { primary: "openai/gpt-4o", fallbacks: ["anthropic/claude-sonnet-4"] } }
          }
        }
        """#

        let originalRoot = try decodeJSON5(json5)
        let (selection, warning) = ConfigModelAccess.readModelSelection(from: originalRoot)

        XCTAssertNil(warning)

        var updatedSelection = selection
        updatedSelection.primary = "google/gemini-pro"
        updatedSelection.fallbacks = ["openai/gpt-4o", "anthropic/claude-sonnet-4"]

        var root = originalRoot
        ConfigModelAccess.writeModelSelection(updatedSelection, to: &root)

        let (roundTripped, roundTripWarning) = ConfigModelAccess.readModelSelection(from: root)
        XCTAssertNil(roundTripWarning)
        XCTAssertEqual(roundTripped, updatedSelection)
    }
}
#endif
