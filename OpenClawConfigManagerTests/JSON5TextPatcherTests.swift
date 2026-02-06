import XCTest
@testable import OpenClawConfigManager

final class JSON5TextPatcherTests: XCTestCase {
    
    let sampleJSON5 = """
{
  agents: {
    defaults: {
      model: {
        primary: 'google-antigravity/gemini-3-pro-high',
        fallbacks: [
          'anthropic/claude-sonnet-4-5',
          'openai/gpt-4o',
        ],
      },
    },
  },
}
"""
    
    func testPatchPrimary_preservesSingleQuotes() throws {
        let result = try JSON5TextPatcher.patchPrimary(
            in: sampleJSON5,
            newValue: "anthropic/claude-opus-4-5"
        )
        
        XCTAssertTrue(result.contains("primary: 'anthropic/claude-opus-4-5'"))
        XCTAssertFalse(result.contains("gemini-3-pro-high"))
    }
    
    func testPatchFallbacks_preservesFormat() throws {
        let result = try JSON5TextPatcher.patchFallbacks(
            in: sampleJSON5,
            newValues: ["openai/gpt-5", "google/gemini-2.5-pro"]
        )
        
        XCTAssertTrue(result.contains("'openai/gpt-5'"))
        XCTAssertTrue(result.contains("'google/gemini-2.5-pro'"))
        XCTAssertFalse(result.contains("claude-sonnet-4-5"))
    }
    
    func testPatchBoth_preservesStructure() throws {
        var result = try JSON5TextPatcher.patchPrimary(
            in: sampleJSON5,
            newValue: "new/primary-model"
        )
        result = try JSON5TextPatcher.patchFallbacks(
            in: result,
            newValues: ["fallback/one", "fallback/two"]
        )
        
        XCTAssertTrue(result.contains("primary: 'new/primary-model'"))
        XCTAssertTrue(result.contains("'fallback/one'"))
        XCTAssertTrue(result.contains("'fallback/two'"))
        XCTAssertTrue(result.contains("agents:"))
        XCTAssertTrue(result.contains("defaults:"))
    }
    
    func testPatchPrimary_withDoubleQuotes() throws {
        let jsonWithDoubleQuotes = """
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "google/gemini",
        "fallbacks": []
      }
    }
  }
}
"""
        let result = try JSON5TextPatcher.patchPrimary(
            in: jsonWithDoubleQuotes,
            newValue: "anthropic/claude"
        )
        
        XCTAssertTrue(result.contains("\"primary\": \"anthropic/claude\""))
    }
    
    func testPatchPrimary_pathNotFound_throws() {
        let invalidJSON = "{ foo: 'bar' }"
        
        XCTAssertThrowsError(try JSON5TextPatcher.patchPrimary(
            in: invalidJSON,
            newValue: "test"
        )) { error in
            guard case JSON5TextPatcher.PatchError.pathNotFound = error else {
                XCTFail("Expected pathNotFound error")
                return
            }
        }
    }
    
    func testFindValueSpan_findsCorrectRange() {
        let path = ["agents", "defaults", "model", "primary"]
        let span = JSON5TextPatcher.findValueSpan(in: sampleJSON5, path: path)
        
        XCTAssertNotNil(span)
        if let span = span {
            let value = String(sampleJSON5[span.range])
            XCTAssertEqual(value, "'google-antigravity/gemini-3-pro-high'")
            XCTAssertEqual(span.quoteStyle, .single)
        }
    }
    
    func testFindArraySpan_findsCorrectRange() {
        let path = ["agents", "defaults", "model", "fallbacks"]
        let span = JSON5TextPatcher.findArraySpan(in: sampleJSON5, path: path)
        
        XCTAssertNotNil(span)
        if let span = span {
            let value = String(sampleJSON5[span.range])
            XCTAssertTrue(value.hasPrefix("["))
            XCTAssertTrue(value.hasSuffix("]"))
            XCTAssertTrue(value.contains("claude-sonnet-4-5"))
        }
    }
    
    func testPreservesTrailingCommas() throws {
        let result = try JSON5TextPatcher.patchPrimary(
            in: sampleJSON5,
            newValue: "test/model"
        )
        
        let fallbacksLine = result.components(separatedBy: "\n")
            .first { $0.contains("gpt-4o") }
        XCTAssertNotNil(fallbacksLine)
        XCTAssertTrue(fallbacksLine?.hasSuffix(",") ?? false)
    }
    
    func testEmptyFallbacks() throws {
        let result = try JSON5TextPatcher.patchFallbacks(
            in: sampleJSON5,
            newValues: []
        )
        
        XCTAssertTrue(result.contains("fallbacks:"))
        XCTAssertTrue(result.contains("[]") || result.contains("[\n"))
    }
}
