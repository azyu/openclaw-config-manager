import XCTest
@testable import OpenClawConfigManager

final class ConfigViewModelTests: XCTestCase {
    var tempConfigURL: URL!
    
    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempConfigURL = tempDir.appendingPathComponent("openclaw-test-\(UUID().uuidString).json")
        setenv("OPENCLAW_CONFIG_PATH", tempConfigURL.path, 1)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigURL)
        unsetenv("OPENCLAW_CONFIG_PATH")
        super.tearDown()
    }
    
    @MainActor
    func testLoadPopulatesSelections() throws {
        // Arrange: Create a fixture file
        let json = """
        {
          "agents": {
            "defaults": {
              "model": {
                "primary": "anthropic/claude-3-5-sonnet-20241022",
                "fallbacks": ["openai/gpt-4o"]
              }
            }
          }
        }
        """
        try json.data(using: .utf8)?.write(to: tempConfigURL)
        
        // Act
        let viewModel = ConfigViewModel()
        
        // Assert
        XCTAssertEqual(viewModel.selectedPrimary, "anthropic/claude-3-5-sonnet-20241022")
        XCTAssertEqual(viewModel.selectedFallbacks, ["openai/gpt-4o"])
        XCTAssertFalse(viewModel.isDirty)
        XCTAssertNotNil(viewModel.loadedAt)
        XCTAssertEqual(viewModel.statusMessage, "Loaded")
    }
    
    @MainActor
    func testIsDirtyBecomesTrueWhenSelectionChanges() {
        // Act
        let viewModel = ConfigViewModel()
        viewModel.selectedPrimary = "openai/gpt-4o"
        viewModel.updateDirtyState()
        
        // Assert
        XCTAssertTrue(viewModel.isDirty)
    }
    
    @MainActor
    func testSaveWritesToDisk() throws {
        // Arrange
        let viewModel = ConfigViewModel()
        viewModel.selectedPrimary = "google/gemini-2.5-pro"
        viewModel.selectedFallbacks = ["openai/gpt-4o"]
        
        // Act
        viewModel.save()
        
        // Assert
        XCTAssertFalse(viewModel.isDirty)
        XCTAssertNotNil(viewModel.savedAt)
        
        let savedData = try Data(contentsOf: tempConfigURL)
        let savedJson = try JSONSerialization.jsonObject(with: savedData) as? [String: Any]
        let agents = savedJson?["agents"] as? [String: Any]
        let defaults = agents?["defaults"] as? [String: Any]
        let model = defaults?["model"] as? [String: Any]
        
        XCTAssertEqual(model?["primary"] as? String, "google/gemini-2.5-pro")
        XCTAssertEqual(model?["fallbacks"] as? [String], ["openai/gpt-4o"])
    }
    
    @MainActor
    func testReloadDiscardsUnsavedChanges() throws {
        // Arrange: Start with a saved state
        let viewModel = ConfigViewModel()
        viewModel.selectedPrimary = "primary-1"
        viewModel.save()
        
        // Act: Modify but don't save, then reload
        viewModel.selectedPrimary = "primary-changed"
        viewModel.updateDirtyState()
        XCTAssertTrue(viewModel.isDirty)
        
        viewModel.reload()
        
        // Assert
        XCTAssertEqual(viewModel.selectedPrimary, "primary-1")
        XCTAssertFalse(viewModel.isDirty)
    }
    
    @MainActor
    func testFallbackManagement() {
        let viewModel = ConfigViewModel()
        viewModel.selectedPrimary = "some-primary"
        viewModel.save() // Reset state
        XCTAssertFalse(viewModel.isDirty)
        
        // Add
        viewModel.addFallback()
        XCTAssertEqual(viewModel.selectedFallbacks.count, 1)
        XCTAssertEqual(viewModel.selectedFallbacks[0], "")
        // isDirty is false because normalization drops empty strings
        XCTAssertFalse(viewModel.isDirty)
        
        // Update to non-empty
        viewModel.selectedFallbacks[0] = "fallback-1"
        viewModel.updateDirtyState()
        XCTAssertTrue(viewModel.isDirty)
        
        // Save to reset dirty
        viewModel.save()
        XCTAssertFalse(viewModel.isDirty)
        
        // Remove
        viewModel.removeFallback(at: 0)
        XCTAssertEqual(viewModel.selectedFallbacks.count, 0)
        XCTAssertTrue(viewModel.isDirty)
    }
}
