import Foundation
import SusurroCore

/// `Susurro --transcribe file.wav` runs the same pipeline as the app (transcription + cleanup) without hotkeys
/// or paste. `Susurro --clean "text"` runs only the cleanup.
enum DebugCLI {
    static func transcribe(path: String) async -> Int32 {
        await run { pipeline in
            let raw = try await timed("transcripción") { try await pipeline.transcript(wav: URL(fileURLWithPath: path)) }
            print(raw)
            if let cleaner = pipeline.cleaner, !raw.isEmpty {
                print(try await timed("limpieza") { try await cleaner.clean(raw) })
            }
        }
    }

    static func clean(_ text: String) async -> Int32 {
        await run { pipeline in
            guard let cleaner = pipeline.cleaner else { throw CLIError("La limpieza está desactivada o falta GROQ_API_KEY.") }
            print(try await timed("limpieza") { try await cleaner.clean(text) })
        }
    }

    private static func run(_ body: (DictationPipeline) async throws -> Void) async -> Int32 {
        do {
            let pipeline = DictationPipeline(
                config: try ConfigStore.load(), secrets: ConfigStore.secrets(), vocabulary: ConfigStore.vocabulary()
            )
            log(pipeline.summary)
            pipeline.warnings.forEach(log)
            try await body(pipeline)
            return 0
        } catch {
            log(error.localizedDescription)
            return 1
        }
    }

    private static func timed<T>(_ label: String, _ work: () async throws -> T) async throws -> T {
        let start = Date()
        let result = try await work()
        log(String(format: "%@: %.2fs", label, Date().timeIntervalSince(start)))
        return result
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }

    private struct CLIError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
