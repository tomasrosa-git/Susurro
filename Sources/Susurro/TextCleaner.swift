import Foundation
import SusurroCore

/// Groq chat completion that removes filler words and fixes punctuation.
struct TextCleaner: Sendable {
    let apiKey: String
    let model: String

    /// Cleanup must not hold up the paste for long; past this the raw transcript is good enough.
    private static let timeout: TimeInterval = 8

    func clean(_ raw: String) async throws -> String {
        struct Message: Codable {
            let role: String
            let content: String
        }
        struct Request: Encodable {
            let model: String
            let messages: [Message]
            let temperature: Double
            let max_tokens: Int
            let options: [String: Cleanup.ReasoningOption]

            enum CodingKeys: String, CodingKey { case model, messages, temperature, max_tokens }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(model, forKey: .model)
                try container.encode(messages, forKey: .messages)
                try container.encode(temperature, forKey: .temperature)
                try container.encode(max_tokens, forKey: .max_tokens)
                try options.encode(to: encoder)
            }
        }
        struct Response: Decodable {
            struct Choice: Decodable {
                let message: Message
                let finish_reason: String?
            }
            let choices: [Choice]
        }

        let body = try JSONEncoder().encode(Request(
            model: model,
            messages: [
                Message(role: "system", content: Cleanup.systemPrompt),
                Message(role: "user", content: Cleanup.userMessage(for: raw)),
            ],
            temperature: 0,
            max_tokens: Cleanup.maxTokens(for: raw, model: model),
            options: Cleanup.reasoningOptions(model: model)
        ))
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await API.send(request, body: body)
        guard let choice = try JSONDecoder().decode(Response.self, from: data).choices.first,
              choice.finish_reason != "length",
              let cleaned = Cleanup.sanitize(choice.message.content, raw: raw)
        else { return raw }
        return cleaned
    }
}
