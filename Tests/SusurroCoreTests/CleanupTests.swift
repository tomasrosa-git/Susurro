import Testing
@testable import SusurroCore

@Suite struct CleanupTests {
    private let raw = "eh bueno este mañana a las tres tengo una reunión con el equipo"

    @Test func passesThroughCleanOutput() {
        let out = "Mañana a las tres tengo una reunión con el equipo."
        #expect(Cleanup.sanitize(out, raw: raw) == out)
    }

    @Test func trimsWhitespace() {
        #expect(Cleanup.sanitize("\n  Hola, ¿cómo andás?  \n", raw: "hola cómo andás") == "Hola, ¿cómo andás?")
    }

    @Test func stripsEchoedTags() {
        #expect(Cleanup.sanitize("<transcript>\nHola.\n</transcript>", raw: "hola") == "Hola.")
    }

    @Test func stripsPreambles() {
        #expect(Cleanup.sanitize("Here is the cleaned text:\nSee you tomorrow.", raw: "uh see you tomorrow") == "See you tomorrow.")
        #expect(Cleanup.sanitize("Aquí está el texto limpio:\n\nNos vemos mañana.", raw: "eh nos vemos mañana") == "Nos vemos mañana.")
    }

    @Test func keepsColonsThatAreContent() {
        let out = "Lista de compras: pan, leche y huevos."
        #expect(Cleanup.sanitize(out, raw: "lista de compras dos puntos pan leche y huevos") == out)
    }

    @Test func stripsWrappingQuotes() {
        #expect(Cleanup.sanitize("\"Nos vemos mañana.\"", raw: "nos vemos mañana") == "Nos vemos mañana.")
        #expect(Cleanup.sanitize("“Nos vemos mañana.”", raw: "nos vemos mañana") == "Nos vemos mañana.")
        #expect(Cleanup.sanitize("«Nos vemos mañana.»", raw: "nos vemos mañana") == "Nos vemos mañana.")
    }

    @Test func keepsQuotesTheSpeakerDictated() {
        #expect(Cleanup.sanitize("\"Hola.\"", raw: "\"hola\"") == "\"Hola.\"")
    }

    @Test func keepsInnerQuotes() {
        let out = "Me dijo \"ya voy\" y se fue."
        #expect(Cleanup.sanitize(out, raw: "me dijo ya voy y se fue") == out)
    }

    @Test func rejectsEmptyOutput() {
        #expect(Cleanup.sanitize("  \n ", raw: raw) == nil)
        #expect(Cleanup.sanitize("<transcript></transcript>", raw: raw) == nil)
    }

    @Test func rejectsAnswersInsteadOfCleanup() {
        let question = "cuánto es dos más dos"
        let answer = "Dos más dos es cuatro. Es una suma básica: si tenés dos elementos y agregás otros dos, obtenés cuatro en total."
        #expect(Cleanup.sanitize(answer, raw: question) == nil)
    }

    @Test func allowsModestGrowthFromPunctuation() {
        #expect(Cleanup.sanitize("Sí, dale.", raw: "si dale") == "Sí, dale.")
    }

    @Test func reasoningIsTurnedOffOrDownPerModelFamily() {
        #expect(Cleanup.reasoningOptions(model: "qwen/qwen3.8-27b") == ["reasoning_effort": .string("none")])
        #expect(Cleanup.reasoningOptions(model: "openai/gpt-oss-120b") == [
            "reasoning_effort": .string("low"), "include_reasoning": .bool(false),
        ])
        #expect(Cleanup.reasoningOptions(model: "llama-3.3-70b-versatile").isEmpty)
    }

    @Test func maxTokensScaleWithTheTranscript() {
        let short = "cuánto es dos más dos"
        #expect(Cleanup.maxTokens(for: short, model: "qwen/qwen3.8-27b") == short.utf8.count / 3 + 64)
        #expect(Cleanup.maxTokens(for: short, model: "openai/gpt-oss-20b") == short.utf8.count / 3 + 64 + 512)
    }

    @Test func qwenNeverAsksForMoreThanItsPerMinuteLimit() {
        let fiveMinutes = String(repeating: "una frase dictada bastante larga, ", count: 200)
        #expect(Cleanup.maxTokens(for: fiveMinutes, model: "qwen/qwen3.8-27b") == 1000)
        #expect(Cleanup.maxTokens(for: fiveMinutes, model: "openai/gpt-oss-120b") > 1000)
    }

    @Test func userMessageWrapsTranscript() {
        #expect(Cleanup.userMessage(for: "hola") == "<transcript>\nhola\n</transcript>")
    }
}

@Suite struct SpacingTests {
    @Test func addsSpaceAfterAWordOrSentence() {
        #expect(Spacing.join("Chau.", after: ".") == " Chau.")
        #expect(Spacing.join("mundo", after: "a") == " mundo")
        #expect(Spacing.join("y después", after: ",") == " y después")
    }

    @Test func noSpaceAtStartOrAfterWhitespace() {
        #expect(Spacing.join("Hola.", after: nil) == "Hola.")
        #expect(Spacing.join("Hola.", after: " ") == "Hola.")
        #expect(Spacing.join("Hola.", after: "\n") == "Hola.")
        #expect(Spacing.join("Hola.", after: "\t") == "Hola.")
    }

    @Test func noSpaceAfterOpeningCharacters() {
        #expect(Spacing.join("cómo andás?", after: "¿") == "cómo andás?")
        #expect(Spacing.join("nota", after: "(") == "nota")
        #expect(Spacing.join("usuario", after: "@") == "usuario")
    }

    @Test func noSpaceBeforeClosingPunctuation() {
        #expect(Spacing.join(", y algo más", after: "a") == ", y algo más")
        #expect(Spacing.join(".", after: "a") == ".")
    }

    @Test func emptyTextStaysEmpty() {
        #expect(Spacing.join("", after: "a") == "")
    }
}

@Suite struct DotEnvTests {
    @Test func parsesCommonForms() {
        let env = DotEnv.parse("""
            # keys
            GROQ_API_KEY=gsk_abc
            export OPENAI_API_KEY="sk-xyz"
              SPACED = 'quoted value'

            NO_EQUALS
            EMPTY=
            URL=https://x.test/?a=b
            """)
        #expect(env["GROQ_API_KEY"] == "gsk_abc")
        #expect(env["OPENAI_API_KEY"] == "sk-xyz")
        #expect(env["SPACED"] == "quoted value")
        #expect(env["EMPTY"] == "")
        #expect(env["URL"] == "https://x.test/?a=b")
        #expect(env["NO_EQUALS"] == nil)
        #expect(env.count == 5)
    }

    @Test func handlesCRLF() {
        #expect(DotEnv.parse("A=1\r\nB=2\r\n") == ["A": "1", "B": "2"])
    }
}
