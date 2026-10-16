import Foundation
import SusurroCore

/// Groq chat completion that removes filler words and fixes punctuation.
struct TextCleaner: Sendable {
    let apiKey: String
    let model: String
    let terms: [String]

    /// Cleanup must not hold up the paste for long; past this the raw transcript is good enough.
    private static let timeout: TimeInterval = 8

    func clean(_ raw: String) async throws -> String {
        guard let reply = try await GroqChat.complete(
            apiKey: apiKey,
            model: model,
            system: Cleanup.systemPrompt(terms: terms),
            user: Cleanup.userMessage(for: raw),
            maxTokens: Cleanup.maxTokens(for: raw, model: model),
            timeout: Self.timeout
        ), !reply.truncated, let cleaned = Cleanup.sanitize(reply.content, raw: raw)
        else { return raw }
        return cleaned
    }
}
