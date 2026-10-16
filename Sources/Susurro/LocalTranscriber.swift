import Foundation
import SusurroCore

struct LocalTranscriber: Sendable {
    enum TranscriberError: LocalizedError {
        case missingCLI(String)
        case missingModel(String)
        case failed(status: Int32, detail: String)

        var errorDescription: String? {
            switch self {
            case .missingCLI(let path): "No se encontró whisper-cli en \(path) (brew install whisper-cpp)."
            case .missingModel(let path): "No se encontró el modelo en \(path)."
            case .failed(let status, let detail): "whisper-cli terminó con código \(status): \(detail)"
            }
        }
    }

    let cli: URL
    let model: URL
    let language: String
    let prompt: String?

    init(config: Config, prompt: String?) {
        cli = URL(fileURLWithPath: (config.whisperCLI as NSString).expandingTildeInPath)
        model = config.resolvedModelPath(modelsDir: Paths.modelsDir)
        language = config.language
        self.prompt = prompt
    }

    func transcribe(wav: URL) async throws -> String {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: cli.path) else { throw TranscriberError.missingCLI(cli.path) }
        guard fm.fileExists(atPath: model.path) else { throw TranscriberError.missingModel(model.path) }

        let base = wav.deletingPathExtension()
        let textFile = base.appendingPathExtension("txt")
        let logFile = base.appendingPathExtension("log")
        fm.createFile(atPath: logFile.path, contents: nil)
        defer {
            try? fm.removeItem(at: textFile)
            try? fm.removeItem(at: logFile)
        }

        let process = Process()
        process.executableURL = cli
        process.arguments = [
            "-m", model.path, "-f", wav.path, "-l", language,
            "-nt", "-np", "-otxt", "-of", base.path,
        ] + (prompt.map { ["--prompt", $0] } ?? [])
        process.standardOutput = FileHandle.nullDevice
        // A file instead of a pipe: whisper logs enough to stderr to fill a pipe buffer and block.
        process.standardError = try FileHandle(forWritingTo: logFile)

        let handle = ProcessHandle(process)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in continuation.resume() }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            handle.terminate()
        }
        try Task.checkCancellation()

        guard process.terminationStatus == 0 else {
            let log = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
            let lastLine = log.split(separator: "\n").last.map(String.init) ?? ""
            throw TranscriberError.failed(status: process.terminationStatus, detail: lastLine)
        }
        return TranscriptText.normalize(try String(contentsOf: textFile, encoding: .utf8))
    }
}

private final class ProcessHandle: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    func terminate() {
        if process.isRunning { process.terminate() }
    }
}
