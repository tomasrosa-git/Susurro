import Testing
@testable import SusurroCore

@Suite struct HotkeyTests {
    @Test func fnAndGlobe() throws {
        #expect(try Hotkey.parse("fn") == .fn)
        #expect(try Hotkey.parse(" Globe ") == .fn)
    }

    @Test func comboWithAliasesAndCase() throws {
        #expect(try Hotkey.parse("Ctrl+Option+Space") == .combo(keyCode: 49, modifiers: [.control, .option]))
        #expect(try Hotkey.parse("cmd + shift + d") == .combo(keyCode: 2, modifiers: [.command, .shift]))
        #expect(try Hotkey.parse("alt+control+f5") == .combo(keyCode: 96, modifiers: [.control, .option]))
    }

    @Test func modifierOrderDoesNotMatter() throws {
        #expect(try Hotkey.parse("space+ctrl") == Hotkey.parse("ctrl+space"))
    }

    @Test func highFunctionKeysCanStandAlone() throws {
        #expect(try Hotkey.parse("f13") == .combo(keyCode: 105, modifiers: []))
    }

    @Test func rejectsBareTypingKeys() {
        #expect(throws: Hotkey.ParseError.needsModifier("space")) { try Hotkey.parse("space") }
        #expect(throws: Hotkey.ParseError.needsModifier("f5")) { try Hotkey.parse("f5") }
    }

    @Test func rejectsMalformedSpecs() {
        #expect(throws: Hotkey.ParseError.empty) { try Hotkey.parse(" + ") }
        #expect(throws: Hotkey.ParseError.missingKey) { try Hotkey.parse("ctrl+option") }
        #expect(throws: Hotkey.ParseError.multipleKeys) { try Hotkey.parse("ctrl+a+b") }
        #expect(throws: Hotkey.ParseError.unknownToken("hyper")) { try Hotkey.parse("hyper+a") }
        #expect(throws: Hotkey.ParseError.unknownToken("fn")) { try Hotkey.parse("fn+a") }
    }
}
