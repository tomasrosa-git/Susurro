import AppKit
import SusurroCore

/// Session-level event tap. Needs Accessibility; without it `start()` returns false.
@MainActor
final class HotkeyMonitor {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    var onOtherKey: () -> Void = {}
    var onEscape: () -> Void = {}

    private(set) var hotkey: Hotkey
    private var tap: CFMachPort?
    private var fnDown = false
    private var comboDown = false

    private static let fnKeyCode: Int64 = 63
    private static let escapeKeyCode: Int64 = 53

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    func setHotkey(_ hotkey: Hotkey) {
        self.hotkey = hotkey
        fnDown = false
        comboDown = false
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
            guard hotkey == .fn, keyCode == Self.fnKeyCode else { return false }
            let down = event.flags.contains(.maskSecondaryFn)
            guard down != fnDown else { return false }
            fnDown = down
            down ? onPress() : onRelease()
            return false

        case .keyDown:
            if keyCode == Self.escapeKeyCode {
                // Observed, never swallowed: Esc still has to reach the app being typed in.
                onEscape()
                return false
            }
            switch hotkey {
            case .fn:
                if fnDown { onOtherKey() }
                return false
            case .combo(let key, let modifiers):
                guard keyCode == Int64(key) else { return false }
                if comboDown { return true }
                guard Self.modifiers(of: event.flags) == modifiers else { return false }
                comboDown = true
                onPress()
                return true
            }

        case .keyUp:
            guard case .combo(let key, _) = hotkey, comboDown, keyCode == Int64(key) else { return false }
            comboDown = false
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
