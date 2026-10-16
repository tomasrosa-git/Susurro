import Foundation
import Testing
@testable import SusurroCore

@Suite struct ConfigTests {
    @Test func missingKeysFallBackToDefaults() throws {
        let config = try Config.decode(Data(#"{"hotkey": "ctrl+option+space"}"#.utf8))
        #expect(config.hotkey == "ctrl+option+space")
        #expect(config.language == Config.defaults.language)
        #expect(config.whisperModel == Config.defaults.whisperModel)
    }

    @Test func roundTrips() throws {
        let config = Config(
            hotkey: "f13", language: "es", transcriber: .groq, whisperModel: "medium",
            whisperCLI: "/x/whisper-cli", cleanup: false, cleanupModel: "m"
        )
        #expect(try Config.decode(config.encoded()) == config)
    }

    @Test func phaseOneConfigGetsNewDefaults() throws {
        let config = try Config.decode(Data(#"{"hotkey": "fn", "language": "es", "whisperModel": "small"}"#.utf8))
        #expect(config.transcriber == .local)
        #expect(config.cleanup)
        #expect(config.cleanupModel == Config.defaults.cleanupModel)
    }

    @Test func unknownTranscriberIsAnError() {
        #expect(throws: DecodingError.self) { try Config.decode(Data(#"{"transcriber": "azure"}"#.utf8)) }
    }

    @Test func modelNameResolvesInsideModelsDir() {
        let dir = URL(fileURLWithPath: "/models")
        var config = Config.defaults
        config.whisperModel = "medium"
        #expect(config.resolvedModelPath(modelsDir: dir).path == "/models/ggml-medium.bin")
    }

    @Test func modelPathIsUsedAsIs() {
        var config = Config.defaults
        config.whisperModel = "~/m/ggml-large.bin"
        let path = config.resolvedModelPath(modelsDir: URL(fileURLWithPath: "/models")).path
        #expect(path == NSString("~/m/ggml-large.bin").expandingTildeInPath)
    }
}

@Suite struct AudioTests {
    @Test func silenceDetection() {
        #expect(Audio.isSilent([0, 0.001, -0.009]))
        #expect(!Audio.isSilent([0, -0.2, 0]))
        #expect(Audio.isSilent([]))
    }

    @Test func wavHeaderAndSamples() {
        let wav = Audio.wav(samples: [0, 1, -1, 2])
        #expect(wav.count == 44 + 8)
        #expect(String(decoding: wav[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: wav[8..<12], as: UTF8.self) == "WAVE")
        let int16s = stride(from: 44, to: wav.count, by: 2).map {
            Int16(bitPattern: UInt16(wav[$0]) | UInt16(wav[$0 + 1]) << 8)
        }
        #expect(int16s == [0, Int16.max, -Int16.max, Int16.max])
        let rate = wav[24..<28].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        #expect(rate == 16_000)
    }
}

@Suite struct TranscriptTextTests {
    @Test func joinsSegmentsAndDropsMarkers() {
        #expect(TranscriptText.normalize(" Hola, ¿cómo andás?\n Todo bien.\n") == "Hola, ¿cómo andás? Todo bien.")
        #expect(TranscriptText.normalize("[BLANK_AUDIO]\n") == "")
        #expect(TranscriptText.normalize("[Music] hello [ Silence ] world") == "hello world")
    }
}
