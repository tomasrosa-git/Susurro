import Foundation
import SusurroCore

protocol Transcriber: Sendable {
    func transcribe(wav: URL) async throws -> String
}

extension LocalTranscriber: Transcriber {}

/// OpenAI-compatible `/audio/transcriptions` endpoint; Groq exposes the same API.
struct CloudTranscriber: Transcriber {
    let endpoint: URL
    let apiKey: String
    let model: String
    let language: String
    let prompt: String?

    static func groq(apiKey: String, language: String, prompt: String?) -> CloudTranscriber {
        CloudTranscriber(
            endpoint: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!,
            apiKey: apiKey,
            model: "whisper-large-v3-turbo",
            language: language,
            prompt: prompt
        )
    }

    static func openAI(apiKey: String, language: String, prompt: String?) -> CloudTranscriber {
        CloudTranscriber(
            endpoint: URL(string: "https://api.openai.com/v1/audio/transcriptions")!,
            apiKey: apiKey,
            model: "whisper-1",
            language: language,
            prompt: prompt
        )
    }

    func transcribe(wav: URL) async throws -> String {
        let boundary = "susurro-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("model", model)
        field("response_format", "json")
        field("temperature", "0")
        if language != "auto" { field("language", language) }
        if let prompt { field("prompt", prompt) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(try Data(contentsOf: wav))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        struct Response: Decodable { let text: String }
        let data = try await API.send(request, body: body)
        return TranscriptText.normalize(try JSONDecoder().decode(Response.self, from: data).text)
    }
}

enum API {
    struct HTTPError: LocalizedError {
        let host: String
        let status: Int
        let message: String

        var errorDescription: String? { "\(host) respondió \(status): \(message)" }
    }

    static func send(_ request: URLRequest, body: Data) async throws -> Data {
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            struct ErrorBody: Decodable {
                struct Inner: Decodable { let message: String }
                let error: Inner
            }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message
                ?? String(decoding: data.prefix(200), as: UTF8.self)
            throw HTTPError(host: request.url?.host() ?? "API", status: status, message: message)
        }
        return data
    }
}
