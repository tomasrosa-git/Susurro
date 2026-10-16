import Foundation

public struct Config: Codable, Equatable, Sendable {
    public enum Transcriber: String, Codable, Sendable, CaseIterable {
        case local
        case groq
        case openai
    }

    public var hotkey: String
    public var commandHotkey: String
    public var language: String
    public var transcriber: Transcriber
    public var whisperModel: String
    public var whisperCLI: String
    public var cleanup: Bool
    public var cleanupModel: String
    public var restoreClipboard: Bool

    public static let defaults = Config()

    public init(
        hotkey: String = "fn",
        commandHotkey: String = "fn+ctrl",
        language: String = "auto",
        transcriber: Transcriber = .local,
        whisperModel: String = "small",
        whisperCLI: String = "/opt/homebrew/bin/whisper-cli",
        cleanup: Bool = true,
        cleanupModel: String = "qwen/qwen3.8-27b",
        restoreClipboard: Bool = false
    ) {
        self.hotkey = hotkey
        self.commandHotkey = commandHotkey
        self.language = language
        self.transcriber = transcriber
        self.whisperModel = whisperModel
        self.whisperCLI = whisperCLI
        self.cleanup = cleanup
        self.cleanupModel = cleanupModel
        self.restoreClipboard = restoreClipboard
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config.defaults
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? d.hotkey
        commandHotkey = try c.decodeIfPresent(String.self, forKey: .commandHotkey) ?? d.commandHotkey
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        transcriber = try c.decodeIfPresent(Transcriber.self, forKey: .transcriber) ?? d.transcriber
        whisperModel = try c.decodeIfPresent(String.self, forKey: .whisperModel) ?? d.whisperModel
        whisperCLI = try c.decodeIfPresent(String.self, forKey: .whisperCLI) ?? d.whisperCLI
        cleanup = try c.decodeIfPresent(Bool.self, forKey: .cleanup) ?? d.cleanup
        cleanupModel = try c.decodeIfPresent(String.self, forKey: .cleanupModel) ?? d.cleanupModel
        restoreClipboard = try c.decodeIfPresent(Bool.self, forKey: .restoreClipboard) ?? d.restoreClipboard
    }

    public static func decode(_ data: Data) throws -> Config {
        try JSONDecoder().decode(Config.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// "small" / "medium" map to ggml-<name>.bin inside `modelsDir`; anything with a slash is a path.
    public func resolvedModelPath(modelsDir: URL) -> URL {
        if whisperModel.contains("/") {
            return URL(fileURLWithPath: (whisperModel as NSString).expandingTildeInPath)
        }
        return modelsDir.appendingPathComponent("ggml-\(whisperModel).bin")
    }
}
