import Foundation

enum ModelCatalog {
    /// Hardcoded common models
    static let builtInModels: [ModelInfo] = [
        // Google Antigravity models (custom provider)
        ModelInfo(id: "google-antigravity/gemini-3-pro-high", displayName: "Gemini 3 Pro High", provider: "Google Antigravity"),
        ModelInfo(id: "google-antigravity/gemini-3-pro-image", displayName: "Gemini 3 Pro Image", provider: "Google Antigravity"),
        ModelInfo(id: "google-antigravity/gemini-3-flash", displayName: "Gemini 3 Flash", provider: "Google Antigravity"),
        ModelInfo(id: "google-antigravity/claude-opus-4-5-thinking", displayName: "Claude Opus 4.5 Thinking", provider: "Google Antigravity"),
        
        // Antigravity Proxy models
        ModelInfo(id: "antigravity-proxy/claude-opus-4-5-thinking", displayName: "Claude Opus 4.5 Thinking (Proxy)", provider: "Antigravity Proxy"),
        ModelInfo(id: "antigravity-proxy/claude-sonnet-4-5-thinking", displayName: "Claude Sonnet 4.5 Thinking (Proxy)", provider: "Antigravity Proxy"),
        ModelInfo(id: "antigravity-proxy/claude-sonnet-4-5", displayName: "Claude Sonnet 4.5 (Proxy)", provider: "Antigravity Proxy"),
        ModelInfo(id: "antigravity-proxy/gemini-3-pro-high", displayName: "Gemini 3 Pro High (Proxy)", provider: "Antigravity Proxy"),
        ModelInfo(id: "antigravity-proxy/gemini-3-pro-low", displayName: "Gemini 3 Pro Low (Proxy)", provider: "Antigravity Proxy"),
        ModelInfo(id: "antigravity-proxy/gemini-3-flash", displayName: "Gemini 3 Flash (Proxy)", provider: "Antigravity Proxy"),
        
        // Anthropic models
        ModelInfo(id: "anthropic/claude-opus-4-5", displayName: "Claude Opus 4.5", provider: "Anthropic"),
        ModelInfo(id: "anthropic/claude-sonnet-4-5", displayName: "Claude Sonnet 4.5", provider: "Anthropic"),
        ModelInfo(id: "anthropic/claude-sonnet-4-20250514", displayName: "Claude Sonnet 4", provider: "Anthropic"),
        ModelInfo(id: "anthropic/claude-opus-4-20250514", displayName: "Claude Opus 4", provider: "Anthropic"),
        ModelInfo(id: "anthropic/claude-3-5-sonnet-20241022", displayName: "Claude 3.5 Sonnet", provider: "Anthropic"),
        
        // OpenAI Codex models
        ModelInfo(id: "openai-codex/gpt-5.2", displayName: "GPT-5.2 (Codex)", provider: "OpenAI Codex"),
        
        // OpenAI models
        ModelInfo(id: "openai/gpt-4o", displayName: "GPT-4o", provider: "OpenAI"),
        ModelInfo(id: "openai/gpt-4o-mini", displayName: "GPT-4o Mini", provider: "OpenAI"),
        ModelInfo(id: "openai/o1", displayName: "o1", provider: "OpenAI"),
        ModelInfo(id: "openai/o3-mini", displayName: "o3 Mini", provider: "OpenAI"),
        
        // Google models
        ModelInfo(id: "google/gemini-2.5-pro", displayName: "Gemini 2.5 Pro", provider: "Google"),
        ModelInfo(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash", provider: "Google"),
    ]
    
    /// Dynamic models discovered from config (populated at runtime)
    private static var discoveredModels: [ModelInfo] = []
    
    /// All available models (built-in + discovered)
    static var availableModels: [ModelInfo] {
        var all = builtInModels
        for model in discoveredModels {
            if !all.contains(where: { $0.id == model.id }) {
                all.append(model)
            }
        }
        return all
    }
    
    /// Discover models from config document
    /// Call this after loading config to populate dynamic models
    static func discoverModels(from root: JSONValue) {
        var discovered: [ModelInfo] = []
        
        // Read from agents.defaults.models (aliased models)
        if let modelsObj = root["agents"]?["defaults"]?["models"]?.objectValue {
            for (modelId, _) in modelsObj {
                let provider = modelId.components(separatedBy: "/").first ?? "Unknown"
                let name = modelId.components(separatedBy: "/").last ?? modelId
                discovered.append(ModelInfo(
                    id: modelId,
                    displayName: name.replacingOccurrences(of: "-", with: " ").capitalized,
                    provider: provider.capitalized
                ))
            }
        }
        
        // Read from models.providers (custom provider definitions)
        if let providers = root["models"]?["providers"]?.objectValue {
            for (providerName, providerConfig) in providers {
                if let models = providerConfig["models"]?.arrayValue {
                    for model in models {
                        if let modelId = model["id"]?.stringValue,
                           let modelName = model["name"]?.stringValue {
                            let fullId = "\(providerName)/\(modelId)"
                            discovered.append(ModelInfo(
                                id: fullId,
                                displayName: modelName,
                                provider: providerName.capitalized
                            ))
                        }
                    }
                }
            }
        }
        
        // Read current primary/fallbacks to ensure they're included
        if let modelConfig = root["agents"]?["defaults"]?["model"] {
            var modelIds: [String] = []
            if let primary = modelConfig["primary"]?.stringValue {
                modelIds.append(primary)
            }
            if let fallbacks = modelConfig["fallbacks"]?.arrayValue {
                modelIds.append(contentsOf: fallbacks.compactMap { $0.stringValue })
            }
            if let stringModel = modelConfig.stringValue {
                modelIds.append(stringModel)
            }
            
            for modelId in modelIds {
                if !discovered.contains(where: { $0.id == modelId }) &&
                   !builtInModels.contains(where: { $0.id == modelId }) {
                    let provider = modelId.components(separatedBy: "/").first ?? "Unknown"
                    let name = modelId.components(separatedBy: "/").last ?? modelId
                    discovered.append(ModelInfo(
                        id: modelId,
                        displayName: name.replacingOccurrences(of: "-", with: " ").capitalized,
                        provider: provider.capitalized
                    ))
                }
            }
        }
        
        discoveredModels = discovered
    }

    static func find(by id: String) -> ModelInfo? {
        availableModels.first { $0.id == id }
    }

    static func displayName(for id: String) -> String {
        find(by: id)?.displayName ?? id
    }
}
