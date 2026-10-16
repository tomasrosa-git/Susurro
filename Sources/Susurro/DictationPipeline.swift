import Foundation
import SusurroCore

/// Transcriber and optional cleanup built from config.json plus the keys in .env.
struct DictationPipeline: Sendable {
    let transcriber: any Transcriber
    let cleaner: TextCleaner?
    let summary: String
    let warnings: [String]

    init(config: Config, secrets: [String: String]) {
        var warnings: [String] = []
        func key(_ name: String) -> String? {
            guard let value = secrets[name], !value.isEmpty else { return nil }
            return value
        }

        let transcriberName: String
        switch (config.transcriber, key("GROQ_API_KEY"), key("OPENAI_API_KEY")) {
        case (.groq, let groqKey?, _):
            transcriber = CloudTranscriber.groq(apiKey: groqKey, language: config.language)
            transcriberName = "Groq"
        case (.openai, _, let openAIKey?):
            transcriber = CloudTranscriber.openAI(apiKey: openAIKey, language: config.language)
            transcriberName = "OpenAI"
        case (.local, _, _), (.groq, nil, _), (.openai, _, nil):
            if config.transcriber != .local {
                let name = config.transcriber == .groq ? "GROQ_API_KEY" : "OPENAI_API_KEY"
                warnings.append("Falta \(name) en .env: transcribo con whisper local.")
            }
            transcriber = LocalTranscriber(config: config)
            transcriberName = "whisper local (\(config.whisperModel))"
        }

        if config.cleanup, let groqKey = key("GROQ_API_KEY") {
            cleaner = TextCleaner(apiKey: groqKey, model: config.cleanupModel)
        } else {
            cleaner = nil
            if config.cleanup { warnings.append("Falta GROQ_API_KEY en .env: pego el texto sin limpiar.") }
        }

        summary = "Transcripción: \(transcriberName) · Limpieza: \(cleaner == nil ? "no" : "Groq")"
        self.warnings = warnings
    }
}
