import AppKit
import SusurroCore

/// Session-level event tap. Needs Accessibility; without it `start()` returns false.
@MainActor
final class HotkeyMonitor {
    var onPress: (Trigger) -> Void = { _ in }
    var onRelease: () -> Void = {}
    /// fn held for dictation, then the command modifiers joined it.
    var onUpgradeToCommand: () -> Void = {}
    var onOtherKey: () -> Void = {}
    var onEscape: () -> Void = {}

    private(set) var bindings: HotkeyBindings
    private var tap: CFMachPort?
    /// Trigger of the fn press in progress; nil while fn is up or when it matched neither hotkey.
    private var fnPress: Trigger?
    private var fnDown = false
    private var comboKeyDown: Int64?

    private static let fnKeyCode: Int64 = 63
    private static let escapeKeyCode: Int64 = 53

    init(bindings: HotkeyBindings) {
        self.bindings = bindings
    }

    func setBindings(_ bindings: HotkeyBindings) {
        self.bindings = bindings
        fnDown = false
        fnPress = nil
        comboKeyDown = nil
    }

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    /// Returns true when the event must not reach the focused app.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false

        case .flagsChanged:
            guard bindings.usesFn else { return false }
            let modifiers = Self.modifiers(of: event.flags)
            if keyCode == Self.fnKeyCode {
                let down = event.flags.contains(.maskSecondaryFn)
                guard down != fnDown else { return false }
                fnDown = down
                if down {
                    fnPress = bindings.fnTrigger(modifiers: modifiers)
                    if let fnPress { onPress(fnPress) }
                } else if fnPress != nil {
                    fnPress = nil
                    onRelease()
                }
            } else if fnPress == .dictation, bindings.fnTrigger(modifiers: modifiers) == .command {
                fnPress = .command
                onUpgradeToCommand()
            }
            return false

        case .keyDown:
            if keyCode == Self.escapeKeyCode {
                // Observed, never swallowed: Esc still has to reach the app being typed in.
                onEscape()
                return false
            }
            if fnPress != nil { onOtherKey() }
            if comboKeyDown == keyCode { return true }
            guard comboKeyDown == nil,
                  let trigger = bindings.comboTrigger(keyCode: UInt16(keyCode), modifiers: Self.modifiers(of: event.flags))
            else { return false }
            comboKeyDown = keyCode
            onPress(trigger)
            return true

        case .keyUp:
            guard comboKeyDown == keyCode else { return false }
            comboKeyDown = nil
            onRelease()
            return true

        default:
            return false
        }
    }

    private static func modifiers(of flags: CGEventFlags) -> Modifiers {
        var result: Modifiers = []
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        return result
    }
}

private func hotkeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo!).takeUnretainedValue()
    // The tap's run loop source lives on the main run loop, so this always runs on the main thread.
    nonisolated(unsafe) let event = event
    let swallow = MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
