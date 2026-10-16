import Foundation

public struct Config: Codable, Equatable, Sendable {
    public var hotkey: String
    public var language: String
    public var whisperModel: String
    public var whisperCLI: String

    public static let defaults = Config(
        hotkey: "fn",
        language: "auto",
        whisperModel: "small",
        whisperCLI: "/opt/homebrew/bin/whisper-cli"
    )

    public init(hotkey: String, language: String, whisperModel: String, whisperCLI: String) {
        self.hotkey = hotkey
        self.language = language
        self.whisperModel = whisperModel
        self.whisperCLI = whisperCLI
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config.defaults
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? d.hotkey
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        whisperModel = try c.decodeIfPresent(String.self, forKey: .whisperModel) ?? d.whisperModel
        whisperCLI = try c.decodeIfPresent(String.self, forKey: .whisperCLI) ?? d.whisperCLI
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
