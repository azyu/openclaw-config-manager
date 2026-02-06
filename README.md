# OpenClaw Config Manager

macOS native app for managing OpenClaw AI model configuration.

## Features

- **Primary Model Selection** - Choose your default AI model from a dropdown
- **Fallback Models** - Add, remove, and reorder fallback models
- **JSON5 Support** - Reads JSON5 config files (comments, trailing commas)
- **Safe Saves** - Atomic writes with timestamped backups
- **Structure Preservation** - Only modifies `agents.defaults.model`, preserves all other config

## Requirements

- macOS 14.0+
- Xcode 15.0+ (for building)

## Installation

### Using Xcode

```bash
git clone https://github.com/your-repo/openclaw-config-manager.git
cd openclaw-config-manager
open OpenClawConfigManager.xcodeproj
```

Build and run with ⌘R in Xcode.

### Command Line Build

```bash
# Clone and navigate
git clone https://github.com/your-repo/openclaw-config-manager.git
cd openclaw-config-manager

# Build (Debug)
xcodebuild build -scheme OpenClawConfigManager -destination 'platform=macOS'

# Build (Release)
xcodebuild build -scheme OpenClawConfigManager -destination 'platform=macOS' -configuration Release

# Run the app (after build)
open ~/Library/Developer/Xcode/DerivedData/OpenClawConfigManager-*/Build/Products/Release/OpenClawConfigManager.app

# Or specify a custom build directory
xcodebuild build -scheme OpenClawConfigManager -destination 'platform=macOS' -configuration Release -derivedDataPath ./build
open ./build/Build/Products/Release/OpenClawConfigManager.app
```

## Usage

The app reads and writes to `~/.openclaw/openclaw.json`.

1. **Select Primary Model** - Use the dropdown to choose your primary AI model
2. **Add Fallbacks** - Click "Add Fallback" and select models from the dropdown
3. **Reorder Fallbacks** - Drag to reorder fallback priority
4. **Save** - Click Save button (creates backup before saving)
5. **Reload** - Discard unsaved changes and reload from disk

## Config Structure

The app manages the `agents.defaults.model` section:

```json5
{
  agents: {
    defaults: {
      model: {
        primary: "google-antigravity/gemini-3-pro-high",
        fallbacks: [
          "anthropic/claude-sonnet-4-5",
          "openai/gpt-4o"
        ]
      }
    }
  }
}
```

## Available Models

Built-in models include:

| Provider | Models |
|----------|--------|
| Google Antigravity | gemini-3-pro-high, gemini-3-flash, claude-opus-4-5-thinking |
| Antigravity Proxy | claude-opus-4-5-thinking, claude-sonnet-4-5, gemini-3-pro-high |
| Anthropic | claude-opus-4-5, claude-sonnet-4-5, claude-3-5-sonnet |
| OpenAI | gpt-4o, gpt-4o-mini, o1, o3-mini |
| OpenAI Codex | gpt-5.2 |
| Google | gemini-2.5-pro, gemini-2.5-flash |

Models defined in your config's `models.providers` section are automatically discovered.

## Development

### Project Structure

```
OpenClawConfigManager/
├── OpenClawConfigManagerApp.swift    # App entry point
├── ContentView.swift                  # Main UI
├── Config/
│   ├── JSONValue.swift               # JSON5 parsing
│   ├── ConfigDocument.swift          # Config document wrapper
│   ├── ConfigFileManager.swift       # File I/O (atomic + backup)
│   └── ConfigModelAccess.swift       # Model config read/write
├── Models/
│   ├── ModelCatalog.swift            # Available models list
│   ├── ModelInfo.swift               # Model metadata
│   └── ModelSelection.swift          # Selection + normalization
└── ViewModels/
    └── ConfigViewModel.swift         # App state management
```

### Running Tests

```bash
xcodebuild test -scheme OpenClawConfigManager -destination 'platform=macOS'
```

### Test Coverage

- Unit tests for JSON5 parsing, model normalization, config merging
- UI tests for load/save workflows
- 35 tests total

## Safety Features

- **Atomic Writes** - Uses temp file + rename to prevent corruption
- **Backups** - Creates `openclaw.json.bak-YYYYMMDD-HHMMSS` before each save
- **Conflict Detection** - Warns if file changed on disk since last load
- **Structure Preservation** - Never modifies unrelated config keys

## License

MIT
