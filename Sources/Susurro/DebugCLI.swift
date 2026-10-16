import Foundation
import SusurroCore

/// `Susurro --transcribe file.wav` runs the same transcription path as the app, without hotkeys or paste.
enum DebugCLI {
    static func transcribe(path: String) async -> Int32 {
        do {
            let transcriber = LocalTranscriber(config: try ConfigStore.load())
            let start = Date()
            let text = try await transcriber.transcribe(wav: URL(fileURLWithPath: path))
            print(text)
            FileHandle.standardError.write(Data(String(format: "%.2fs\n", Date().timeIntervalSince(start)).utf8))
            return 0
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            return 1
        }
    }
}
