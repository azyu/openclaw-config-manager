# AGENTS.md - Agent Knowledge Base

## OpenClaw Configuration

### Config File Location
- **Path**: `~/.openclaw/openclaw.json`
- **Format**: JSON5 (supports comments, trailing commas, unquoted keys, single quotes)
- **Encoding**: UTF-8

### Model ID Format
Model IDs follow `provider/model-name` format:
```
google-antigravity/gemini-3-pro-high
anthropic/claude-sonnet-4-5
openai-codex/gpt-5.2
antigravity-proxy/claude-opus-4-5-thinking
```

**CRITICAL**: Provider names vary significantly:
- `google-antigravity` (custom provider)
- `antigravity-proxy` (local proxy)
- `anthropic` (direct API)
- `openai-codex` (not just `openai`)

### Config Structure

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "provider/model-name",
        "fallbacks": ["provider/model1", "provider/model2"]
      },
      "models": {
        "provider/model": { "alias": "shortname" }
      }
    }
  },
  "models": {
    "providers": {
      "provider-name": {
        "baseUrl": "...",
        "models": [
          { "id": "model-id", "name": "Display Name" }
        ]
      }
    }
  }
}
```

### Model Sources
Models can come from:
1. `agents.defaults.model.primary` / `fallbacks` - Currently selected
2. `agents.defaults.models` - Aliased models
3. `models.providers.*.models` - Custom provider definitions

---

## Lessons Learned (Mistakes Made)

### 1. Hardcoded Model IDs Were Wrong
**Problem**: Initially hardcoded models like `anthropic/claude-sonnet-4-20250514` but real config used `google-antigravity/gemini-3-pro-high`.

**Solution**: 
- Read actual config file to understand real model IDs
- Implement dynamic model discovery from config
- Keep hardcoded list updated with common models

### 2. JSONEncoder Default Output is Minified
**Problem**: `JSONEncoder()` with default settings outputs single-line JSON, destroying readability.

**Wrong**:
```swift
let encoder = JSONEncoder()
let data = try encoder.encode(root)
// Output: {"agents":{"defaults":{...}}}
```

**Correct**:
```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(root)
```

### 3. sortedKeys Changes Key Order
**Problem**: `.sortedKeys` option alphabetizes keys, changing original order.

**Impact**: 
- `"primary"` comes after `"fallbacks"` alphabetically
- May confuse users expecting original order
- Tests must account for this

### 4. UI Test Model ID Mismatch
**Problem**: UI tests had hardcoded model ID lists that didn't match updated ModelCatalog.

**Solution**: Keep test `expectedModelId()` function in sync with `ModelCatalog.builtInModels` order.

### 5. JSON5 Read vs JSON Write
**Problem**: App reads JSON5 but writes standard JSON.

**Implications**:
- Comments in original file are lost on save
- Trailing commas removed
- Unquoted keys become quoted
- This is documented behavior, not a bug

---

## SwiftUI/macOS Patterns

### MenuBar App (MenuBarExtra)
```swift
@main
struct App: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image("IconName")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
```

Key settings for MenuBar apps:
- `Info.plist`: Add `LSUIElement = true` to hide Dock icon
- Icon sizes: 18x18 @1x, 36x36 @2x, 54x54 @3x (template images)
- Window size: Set via `.frame(width:height:)` on ContentView

### JSON5 Decoding (macOS 14+)
```swift
let decoder = JSONDecoder()
decoder.allowsJSON5 = true
let root = try decoder.decode(JSONValue.self, from: data)
```

### Atomic File Write with Backup
```swift
// 1. Create backup
let backupURL = originalURL.deletingLastPathComponent()
    .appendingPathComponent("file.bak-\(timestamp)")
try FileManager.default.copyItem(at: originalURL, to: backupURL)

// 2. Write to temp file
let tempURL = directory.appendingPathComponent("file.tmp-\(UUID())")
try data.write(to: tempURL)

// 3. Atomic replace
try FileManager.default.replaceItemAt(originalURL, withItemAt: tempURL)
```

### Environment Variable Override for Testing
```swift
static var configURL: URL {
    if let override = ProcessInfo.processInfo.environment["OPENCLAW_CONFIG_PATH"] {
        return URL(fileURLWithPath: override)
    }
    return defaultURL
}
```

### Dynamic Model Discovery
```swift
static func discoverModels(from root: JSONValue) {
    // Read from agents.defaults.models
    // Read from models.providers.*.models
    // Read from current primary/fallbacks
}
```

---

## Testing Notes

### UI Test Accessibility Identifiers
Required identifiers:
- `primaryModelPicker`
- `addFallbackButton`
- `saveButton`
- `reloadButton`
- `statusLabel`

### Test Fixture Location
- Bundle: `OpenClawConfigManagerUITests/Fixtures/`
- Files: `valid-object-form.json5`, `invalid.json5`, etc.

### Environment Setup for Tests
```swift
app.launchEnvironment["OPENCLAW_CONFIG_PATH"] = tempConfigPath.path
```

---

## Build & Verification

```bash
# Build
xcodebuild build -scheme OpenClawConfigManager -destination 'platform=macOS'

# Test
xcodebuild test -scheme OpenClawConfigManager -destination 'platform=macOS'

# Release build
xcodebuild build -scheme OpenClawConfigManager -destination 'platform=macOS' -configuration Release
```

### App Sandbox
- **Status**: DISABLED
- **Reason**: Direct access to `~/.openclaw/openclaw.json` required
- **Alternative**: Security-scoped bookmarks with user file selection
