import Foundation

public struct Modifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = Modifiers(rawValue: 1 << 0)
    public static let option = Modifiers(rawValue: 1 << 1)
    public static let shift = Modifiers(rawValue: 1 << 2)
    public static let command = Modifiers(rawValue: 1 << 3)
}

public enum Hotkey: Equatable, Sendable {
    /// fn / 🌐, optionally held together with modifiers ("fn+ctrl").
    case fn(Modifiers)
    case combo(keyCode: UInt16, modifiers: Modifiers)

    public enum ParseError: Error, Equatable {
        case empty
        case unknownToken(String)
        case missingKey
        case multipleKeys
        case needsModifier(String)
        case fnWithKey(String)
    }

    public static func parse(_ spec: String) throws -> Hotkey {
        let tokens = spec.lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { throw ParseError.empty }

        var modifiers: Modifiers = []
        var key: (name: String, code: UInt16)?
        var fn = false
        for token in tokens {
            if token == "fn" || token == "globe" {
                fn = true
            } else if let modifier = modifierNames[token] {
                modifiers.insert(modifier)
            } else if let code = keyCodes[token] {
                guard key == nil else { throw ParseError.multipleKeys }
                key = (token, code)
            } else {
                throw ParseError.unknownToken(token)
            }
        }
        if fn {
            if let key { throw ParseError.fnWithKey(key.name) }
            return .fn(modifiers)
        }
        guard let key else { throw ParseError.missingKey }
        // A bare letter or space would be swallowed from normal typing.
        if modifiers.isEmpty && !standaloneKeys.contains(key.name) {
            throw ParseError.needsModifier(key.name)
        }
        return .combo(keyCode: key.code, modifiers: modifiers)
    }

    static let modifierNames: [String: Modifiers] = [
        "ctrl": .control, "control": .control,
        "opt": .option, "option": .option, "alt": .option,
        "shift": .shift,
        "cmd": .command, "command": .command,
    ]

    static let standaloneKeys: Set<String> = Set((13...19).map { "f\($0)" })

    // Virtual key codes from HIToolbox/Events.h (ANSI layout).
    static let keyCodes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "return": 36, "enter": 36, "tab": 48, "space": 49, "delete": 51, "backspace": 51,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111, "f13": 105, "f14": 107, "f15": 113,
        "f16": 106, "f17": 64, "f18": 79, "f19": 80,
    ]
}

public enum Trigger: Equatable, Sendable {
    case dictation
    case command
}

/// Which of the two configured hotkeys a key event belongs to. The command hotkey is checked first because the
/// default pair shares fn: "fn+ctrl" is a command, plain fn (with or without other modifiers) is dictation.
public struct HotkeyBindings: Equatable, Sendable {
    public let dictation: Hotkey
    public let command: Hotkey?

    public init(dictation: Hotkey, command: Hotkey?) {
        self.dictation = dictation
        self.command = command == dictation ? nil : command
    }

    public var usesFn: Bool {
        [dictation, command].contains { if case .fn = $0 { true } else { false } }
    }

    public func fnTrigger(modifiers: Modifiers) -> Trigger? {
        if case .fn(let required) = command, modifiers.isSuperset(of: required) { return .command }
        if case .fn(let required) = dictation, modifiers.isSuperset(of: required) { return .dictation }
        return nil
    }

    public func comboTrigger(keyCode: UInt16, modifiers: Modifiers) -> Trigger? {
        if command == .combo(keyCode: keyCode, modifiers: modifiers) { return .command }
        if dictation == .combo(keyCode: keyCode, modifiers: modifiers) { return .dictation }
        return nil
    }
}
