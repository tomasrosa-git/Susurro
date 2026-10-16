import Testing
@testable import SusurroCore

@Suite struct CommandTests {
    @Test func promptDependsOnSelection() {
        #expect(Command.systemPrompt(hasSelection: true, terms: []).contains("<selection>"))
        #expect(!Command.systemPrompt(hasSelection: false, terms: []).contains("<selection>"))
    }

    @Test func promptListsDictionaryTerms() {
        #expect(Command.systemPrompt(hasSelection: false, terms: ["Queleo", "Neon"]).hasSuffix("Queleo, Neon."))
        #expect(!Command.systemPrompt(hasSelection: false, terms: []).contains("Spell these"))
    }

    @Test func userMessageWithAndWithoutSelection() {
        #expect(Command.userMessage(instruction: "más formal", selection: "che") ==
            "<selection>\nche\n</selection>\n\n<instruction>\nmás formal\n</instruction>")
        #expect(Command.userMessage(instruction: "un mail", selection: nil) == "<instruction>\nun mail\n</instruction>")
    }

    @Test func maxTokensStaysUnderQwenCap() {
        #expect(Command.maxTokens(selection: nil, model: "qwen/qwen3.8-27b") == 400)
        #expect(Command.maxTokens(selection: String(repeating: "a", count: 9000), model: "qwen/qwen3.8-27b") == 1000)
        #expect(Command.maxTokens(selection: nil, model: "openai/gpt-oss-120b") == 912)
    }

    @Test func passesCleanOutputThrough() {
        #expect(Command.sanitize("Estimado Juan:\n\nLe escribo para...", selection: nil) == "Estimado Juan:\n\nLe escribo para...")
    }

    @Test func stripsTagsAndPreamble() {
        #expect(Command.sanitize("<output>Hello there.</output>", selection: "hola") == "Hello there.")
        #expect(Command.sanitize("Aquí está el texto:\nHello there.", selection: "hola") == "Hello there.")
    }

    @Test func stripsWrappingQuotesUnlessSelectionHadThem() {
        #expect(Command.sanitize("\"Hello.\"", selection: "hola") == "Hello.")
        #expect(Command.sanitize("\"Hello.\"", selection: "\"hola.\"") == "\"Hello.\"")
    }

    @Test func stripsWrappingFenceUnlessSelectionWasFenced() {
        #expect(Command.sanitize("```\nlet x = 1\n```", selection: "x es uno") == "let x = 1")
        #expect(Command.sanitize("```swift\nlet x = 1\n```", selection: "```\nvar x = 1\n```") == "```swift\nlet x = 1\n```")
    }

    @Test func emptyOutputIsRejected() {
        #expect(Command.sanitize("  <output></output> ", selection: nil) == nil)
    }
}
