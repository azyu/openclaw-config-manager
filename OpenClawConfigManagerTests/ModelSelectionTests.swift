import XCTest
@testable import OpenClawConfigManager

final class ModelSelectionTests: XCTestCase {
    
    func testNormalizationRemovesEmptyStrings() {
        let selection = ModelSelection(primary: "gpt-4o", fallbacks: ["", "  ", "claude-sonnet"])
        let normalized = selection.normalized()
        
        XCTAssertEqual(normalized.fallbacks, ["claude-sonnet"])
    }
    
    func testNormalizationRemovesDuplicatesFromFallbacks() {
        let selection = ModelSelection(primary: "gpt-4o", fallbacks: ["claude-sonnet", "claude-sonnet", "gemini-pro"])
        let normalized = selection.normalized()
        
        XCTAssertEqual(normalized.fallbacks, ["claude-sonnet", "gemini-pro"])
    }
    
    func testNormalizationRemovesPrimaryFromFallbacks() {
        let selection = ModelSelection(primary: "gpt-4o", fallbacks: ["gpt-4o", "claude-sonnet"])
        let normalized = selection.normalized()
        
        XCTAssertEqual(normalized.primary, "gpt-4o")
        XCTAssertEqual(normalized.fallbacks, ["claude-sonnet"])
    }
    
    func testNormalizationPreservesOrder() {
        let selection = ModelSelection(primary: "gpt-4o", fallbacks: ["claude-sonnet", "gemini-pro", "o1"])
        let normalized = selection.normalized()
        
        XCTAssertEqual(normalized.fallbacks, ["claude-sonnet", "gemini-pro", "o1"])
    }
    
    func testUnknownModelIdsArePreserved() {
        let selection = ModelSelection(primary: "unknown/model", fallbacks: ["another/unknown"])
        let normalized = selection.normalized()
        
        XCTAssertEqual(normalized.primary, "unknown/model")
        XCTAssertEqual(normalized.fallbacks, ["another/unknown"])
        
        XCTAssertFalse(ModelSelection.isKnown("unknown/model"))
        XCTAssertTrue(ModelSelection.isKnown("openai/gpt-4o"))
    }
    
    func testNormalizationTrimsWhitespace() {
        let selection = ModelSelection(primary: "  gpt-4o  ", fallbacks: [" claude-sonnet ", " gemini-pro"])
        let normalized = selection.normalized()
        
        XCTAssertEqual(normalized.primary, "gpt-4o")
        XCTAssertEqual(normalized.fallbacks, ["claude-sonnet", "gemini-pro"])
    }
}
