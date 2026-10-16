import Foundation
import SusurroCore

/// Transcriber, dictionary and optional cleanup built from config.json, diccionario.txt and the keys in .env.
struct DictationPipeline: Sendable {
    let transcriber: any Transcriber
    let vocabulary: Vocabulary
    let cleaner: TextCleaner?
    let commander: TextCommander?
    let summary: String
    let warnings: [String]

    init(config: Config, secrets: [String: String], vocabulary: Vocabulary) {
        var warnings: [String] = []
        func key(_ name: String) -> String? {
            guard let value = secrets[name], !value.isEmpty else { return nil }
            return value
        }

        let transcriberName: String
        switch (config.transcriber, key("GROQ_API_KEY"), key("OPENAI_API_KEY")) {
        case (.groq, let groqKey?, _):
            transcriber = CloudTranscriber.groq(apiKey: groqKey, language: config.language, prompt: vocabulary.whisperPrompt)
            transcriberName = "Groq"
        case (.openai, _, let openAIKey?):
            transcriber = CloudTranscriber.openAI(apiKey: openAIKey, language: config.language, prompt: vocabulary.whisperPrompt)
            transcriberName = "OpenAI"
        case (.local, _, _), (.groq, nil, _), (.openai, _, nil):
            if config.transcriber != .local {
                let name = config.transcriber == .groq ? "GROQ_API_KEY" : "OPENAI_API_KEY"
                warnings.append("Falta \(name) en .env: transcribo con whisper local.")
            }
            transcriber = LocalTranscriber(config: config, prompt: vocabulary.whisperPrompt)
            transcriberName = "whisper local (\(config.whisperModel))"
        }

        commander = key("GROQ_API_KEY").map {
            TextCommander(apiKey: $0, model: config.cleanupModel, terms: vocabulary.terms)
        }

        if config.cleanup, let groqKey = key("GROQ_API_KEY") {
            cleaner = TextCleaner(apiKey: groqKey, model: config.cleanupModel, terms: vocabulary.terms)
        } else {
            cleaner = nil
            if config.cleanup { warnings.append("Falta GROQ_API_KEY en .env: pego el texto sin limpiar.") }
        }

        self.vocabulary = vocabulary
        summary = "Transcripción: \(transcriberName) · Limpieza: \(cleaner == nil ? "no" : "Groq")"
            + " · Diccionario: \(vocabulary.terms.count)"
        self.warnings = warnings
    }

    /// Replacements run before cleanup so the LLM already sees the right spelling.
    func transcript(wav: URL) async throws -> String {
        vocabulary.apply(to: try await transcriber.transcribe(wav: wav))
    }
}
