#if canImport(XCTest)
import XCTest

final class OpenClawConfigManagerUITests: XCTestCase {
    var app: XCUIApplication!
    var tempDir: URL!
    var configPath: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        configPath = tempDir.appendingPathComponent("openclaw.json")

        app = XCUIApplication()
        app.launchEnvironment["OPENCLAW_CONFIG_PATH"] = configPath.path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadExistingConfigAndDisplayModels() throws {
        try copyFixture(named: "valid-object-form")

        app.launch()

        let primaryPicker = app.popUpButtons["primaryModelPicker"]
        XCTAssertTrue(primaryPicker.waitForExistence(timeout: 5))

        primaryPicker.click()
        let menuItems = primaryPicker.menuItems
        XCTAssertTrue(menuItems.element(boundBy: 0).waitForExistence(timeout: 5))
        let selectedIndex = selectedMenuIndex(in: menuItems)
        XCTAssertNotNil(selectedIndex)
        XCTAssertNotEqual(selectedIndex, 0)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testChangeAndSave() throws {
        try copyFixture(named: "valid-object-form")
        let initialMtime = try fileModificationDate(for: configPath)

        app.launch()

        let primaryPicker = app.popUpButtons["primaryModelPicker"]
        XCTAssertTrue(primaryPicker.waitForExistence(timeout: 5))
        selectPrimaryMenuItem(primaryPicker: primaryPicker, at: 2)

        let saveButton = app.buttons.matching(identifier: "saveButton").firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.click()

        XCTAssertTrue(waitForFileModification(after: initialMtime, url: configPath))

        let root = try readConfigObject()
        let model = (((root["agents"] as? [String: Any])?["defaults"] as? [String: Any])?["model"] as? [String: Any])?["primary"] as? String
        XCTAssertEqual(model, expectedModelId(forMenuIndex: 2))
    }

    func testInvalidJSON5ShowsError() throws {
        try copyFixture(named: "invalid")

        app.launch()

        let dialog = waitForErrorDialog()
        XCTAssertNotNil(dialog)
        dialog?.buttons.firstMatch.tap()
    }

    func testUnrelatedKeysPreservedAfterSave() throws {
        try copyFixture(named: "with-unrelated-keys")
        let initialMtime = try fileModificationDate(for: configPath)

        app.launch()

        let primaryPicker = app.popUpButtons["primaryModelPicker"]
        XCTAssertTrue(primaryPicker.waitForExistence(timeout: 5))
        selectPrimaryMenuItem(primaryPicker: primaryPicker, at: 4)

        let saveButton = app.buttons.matching(identifier: "saveButton").firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.click()

        XCTAssertTrue(waitForFileModification(after: initialMtime, url: configPath))

        let root = try readConfigObject()
        let agents = root["agents"] as? [String: Any]
        let defaults = agents?["defaults"] as? [String: Any]
        let extra = agents?["extra"] as? [String: Any]
        let gateway = root["gateway"] as? [String: Any]
        let analytics = root["analytics"] as? [String: Any]
        let model = defaults?["model"] as? [String: Any]

        XCTAssertEqual(defaults?["workspace"] as? String, "~/workspace")
        XCTAssertEqual(defaults?["timeoutSeconds"] as? Int, 30)
        XCTAssertEqual(extra?["keep"] as? Bool, true)
        XCTAssertEqual(gateway?["port"] as? Int, 18789)
        XCTAssertEqual(analytics?["enabled"] as? Bool, true)
        let sampleRate = (analytics?["sampleRate"] as? NSNumber)?.doubleValue
        XCTAssertNotNil(sampleRate)
        XCTAssertEqual(sampleRate ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(model?["primary"] as? String, expectedModelId(forMenuIndex: 4))
    }
}

private extension OpenClawConfigManagerUITests {
    func copyFixture(named name: String) throws {
        let bundle = Bundle(for: Self.self)
        let fixture = bundle.url(
            forResource: name,
            withExtension: "json5",
            subdirectory: "Fixtures"
        ) ?? bundle.url(forResource: name, withExtension: "json5")
        guard let fixture else {
            XCTFail("Missing fixture: \(name).json5")
            return
        }
        if FileManager.default.fileExists(atPath: configPath.path) {
            try FileManager.default.removeItem(at: configPath)
        }
        try FileManager.default.copyItem(at: fixture, to: configPath)
    }

    func readConfigObject() throws -> [String: Any] {
        let data = try Data(contentsOf: configPath)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }

    func fileModificationDate(for url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.modificationDate] as? Date) ?? Date.distantPast
    }

    func waitForFileModification(after date: Date, url: URL) -> Bool {
        let predicate = NSPredicate { _, _ in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let mtime = attributes[.modificationDate] as? Date else {
                return false
            }
            return mtime > date
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    func waitForErrorDialog() -> XCUIElement? {
        let candidates = [app.alerts.firstMatch, app.dialogs.firstMatch, app.sheets.firstMatch]
        let predicate = NSPredicate { _, _ in
            candidates.contains { $0.exists }
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        guard result == .completed else { return nil }
        return candidates.first { $0.exists }
    }

    func selectedMenuIndex(in menuItems: XCUIElementQuery) -> Int? {
        for index in 0..<menuItems.count {
            let item = menuItems.element(boundBy: index)
            if item.isSelected {
                return index
            }
        }
        return nil
    }

    func selectPrimaryMenuItem(primaryPicker: XCUIElement, at index: Int) {
        primaryPicker.click()
        let menuItems = primaryPicker.menuItems
        XCTAssertTrue(menuItems.element(boundBy: index).waitForExistence(timeout: 5))
        menuItems.element(boundBy: index).click()
    }

    func expectedModelId(forMenuIndex index: Int) -> String? {
        let modelIds = [
            "google-antigravity/gemini-3-pro-high",
            "google-antigravity/gemini-3-pro-image",
            "google-antigravity/gemini-3-flash",
            "google-antigravity/claude-opus-4-5-thinking",
            "antigravity-proxy/claude-opus-4-5-thinking",
            "antigravity-proxy/claude-sonnet-4-5-thinking",
            "antigravity-proxy/claude-sonnet-4-5",
            "antigravity-proxy/gemini-3-pro-high",
            "antigravity-proxy/gemini-3-pro-low",
            "antigravity-proxy/gemini-3-flash",
            "anthropic/claude-opus-4-5",
            "anthropic/claude-sonnet-4-5",
            "anthropic/claude-sonnet-4-20250514",
            "anthropic/claude-opus-4-20250514",
            "anthropic/claude-3-5-sonnet-20241022",
            "openai-codex/gpt-5.2",
            "openai/gpt-4o",
            "openai/gpt-4o-mini",
            "openai/o1",
            "openai/o3-mini",
            "google/gemini-2.5-pro",
            "google/gemini-2.5-flash"
        ]
        guard index > 0, index <= modelIds.count else { return nil }
        return modelIds[index - 1]
    }
}
#endif
