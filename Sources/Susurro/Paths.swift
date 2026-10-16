import Foundation
import SusurroCore

enum Paths {
    static let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/susurro")
    static let configFile = configDir.appendingPathComponent("config.json")
    static let envFile = configDir.appendingPathComponent(".env")
    static let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Susurro/models")
}

enum ConfigStore {
    static func load() throws -> Config {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Paths.configFile.path) else {
            try fm.createDirectory(at: Paths.configDir, withIntermediateDirectories: true)
            try Config.defaults.encoded().write(to: Paths.configFile)
            return .defaults
        }
        let data = try Data(contentsOf: Paths.configFile)
        let config = try Config.decode(data)
        // Options added in later versions get written out with their defaults so they're discoverable.
        let encoded = try config.encoded()
        if try keys(of: data) != keys(of: encoded) {
            try encoded.write(to: Paths.configFile)
        }
        return config
    }

    private static func keys(of json: Data) throws -> Set<String> {
        Set((try JSONSerialization.jsonObject(with: json) as? [String: Any])?.keys ?? [:].keys)
    }

    static func secrets() -> [String: String] {
        guard let text = try? String(contentsOf: Paths.envFile, encoding: .utf8) else { return [:] }
        return DotEnv.parse(text)
    }
}
