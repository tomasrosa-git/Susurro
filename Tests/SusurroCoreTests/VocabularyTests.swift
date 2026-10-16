import Testing
@testable import SusurroCore

@Suite struct VocabularyTests {
    private let vocabulary = Vocabulary.parse("""
        # comentario
        Prisma

        que leo -> Queleo
          Neon
        roto ->
        -> sin origen
        Prisma
        """)

    @Test func parsesTermsAndReplacements() {
        #expect(vocabulary.terms == ["Prisma", "Queleo", "Neon"])
        #expect(vocabulary.replacements == [.init(heard: "que leo", written: "Queleo")])
    }

    @Test func templateHasNoEntries() {
        #expect(Vocabulary.parse(Vocabulary.template).isEmpty)
        #expect(Vocabulary.empty.whisperPrompt == nil)
    }

    @Test func whisperPromptListsTerms() {
        #expect(vocabulary.whisperPrompt == "Prisma, Queleo, Neon.")
    }

    @Test func replacesIgnoringCaseAndAccents() {
        #expect(vocabulary.apply(to: "Que leo anda bien") == "Queleo anda bien")
        #expect(vocabulary.apply(to: "abrí qué leó.") == "abrí Queleo.")
    }

    @Test func replacesEveryOccurrence() {
        #expect(vocabulary.apply(to: "que leo y que leo") == "Queleo y Queleo")
    }

    @Test func onlyReplacesWholeWords() {
        #expect(vocabulary.apply(to: "porque leo mucho") == "porque leo mucho")
        #expect(vocabulary.apply(to: "que leon") == "que leon")
    }

    @Test func findsWholeWordAfterRejectedMatch() {
        let v = Vocabulary.parse("aa -> X")
        #expect(v.apply(to: "aaa aa") == "aaa X")
    }

    @Test func keepsPunctuationAroundMatch() {
        #expect(vocabulary.apply(to: "¿que leo?") == "¿Queleo?")
    }

    @Test func replacementIsNotReappliedToItsOwnOutput() {
        let v = Vocabulary.parse("neon -> Neon DB")
        #expect(v.apply(to: "neon") == "Neon DB")
    }

    @Test func textWithoutMatchesIsUnchanged() {
        #expect(vocabulary.apply(to: "nada que ver") == "nada que ver")
        #expect(vocabulary.apply(to: "") == "")
    }
}

@Suite struct CleanupPromptTests {
    @Test func dictionaryRuleOnlyWhenThereAreTerms() {
        #expect(!Cleanup.systemPrompt(terms: []).contains("dictionary"))
        let prompt = Cleanup.systemPrompt(terms: ["Queleo", "Prisma"])
        #expect(prompt.contains("Queleo, Prisma"))
        #expect(prompt.hasSuffix("Output only the cleaned text."))
    }
}
