import Foundation
import SusurroCore

/// One-shot Groq chat completion shared by cleanup and command mode.
enum GroqChat {
    struct Reply {
        let content: String
        let truncated: Bool
    }

    static func complete(
        apiKey: String, model: String, system: String, user: String, maxTokens: Int, timeout: TimeInterval
    ) async throws -> Reply? {
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
            messages: [Message(role: "system", content: system), Message(role: "user", content: user)],
            temperature: 0,
            max_tokens: maxTokens,
            options: Cleanup.reasoningOptions(model: model)
        ))
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await API.send(request, body: body)
        guard let choice = try JSONDecoder().decode(Response.self, from: data).choices.first else { return nil }
        return Reply(content: choice.message.content, truncated: choice.finish_reason == "length")
    }
}
