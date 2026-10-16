import Foundation
import SusurroCore

enum Paths {
    static let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/susurro")
    static let configFile = configDir.appendingPathComponent("config.json")
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
        return try Config.decode(Data(contentsOf: Paths.configFile))
    }
}
