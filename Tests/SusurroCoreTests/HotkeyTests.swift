import Testing
@testable import SusurroCore

@Suite struct HotkeyTests {
    @Test func fnAndGlobe() throws {
        #expect(try Hotkey.parse("fn") == .fn([]))
        #expect(try Hotkey.parse(" Globe ") == .fn([]))
    }

    @Test func fnWithModifiers() throws {
        #expect(try Hotkey.parse("fn+ctrl") == .fn([.control]))
        #expect(try Hotkey.parse("shift+globe+cmd") == .fn([.shift, .command]))
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
        #expect(throws: Hotkey.ParseError.fnWithKey("a")) { try Hotkey.parse("fn+a") }
    }
}

@Suite struct HotkeyBindingsTests {
    private let defaults = HotkeyBindings(dictation: .fn([]), command: .fn([.control]))

    @Test func fnAloneDictatesAndFnCtrlCommands() {
        #expect(defaults.fnTrigger(modifiers: []) == .dictation)
        #expect(defaults.fnTrigger(modifiers: [.control]) == .command)
    }

    @Test func extraModifiersStillMatch() {
        #expect(defaults.fnTrigger(modifiers: [.shift]) == .dictation)
        #expect(defaults.fnTrigger(modifiers: [.control, .shift]) == .command)
    }

    @Test func comboDictationWithFnCommand() {
        let bindings = HotkeyBindings(dictation: .combo(keyCode: 49, modifiers: [.control, .option]), command: .fn([.control]))
        #expect(bindings.usesFn)
        #expect(bindings.fnTrigger(modifiers: []) == nil)
        #expect(bindings.fnTrigger(modifiers: [.control]) == .command)
        #expect(bindings.comboTrigger(keyCode: 49, modifiers: [.control, .option]) == .dictation)
        #expect(bindings.comboTrigger(keyCode: 49, modifiers: [.control]) == nil)
    }

    @Test func comboCommand() {
        let bindings = HotkeyBindings(dictation: .fn([]), command: .combo(keyCode: 8, modifiers: [.control, .option]))
        #expect(bindings.comboTrigger(keyCode: 8, modifiers: [.control, .option]) == .command)
        #expect(bindings.fnTrigger(modifiers: [.control, .option]) == .dictation)
    }

    @Test func commandEqualToDictationIsDropped() {
        let bindings = HotkeyBindings(dictation: .fn([]), command: .fn([]))
        #expect(bindings.command == nil)
        #expect(bindings.fnTrigger(modifiers: []) == .dictation)
    }

    @Test func noFnWhenBothAreCombos() {
        let bindings = HotkeyBindings(dictation: .combo(keyCode: 105, modifiers: []), command: nil)
        #expect(!bindings.usesFn)
    }
}
