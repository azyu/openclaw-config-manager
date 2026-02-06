import Foundation

struct ModelInfo: Identifiable, Hashable {
    let id: String  // e.g. "anthropic/claude-sonnet-4-20250514"
    let displayName: String  // e.g. "Claude Sonnet 4"
    let provider: String  // e.g. "Anthropic"
}
