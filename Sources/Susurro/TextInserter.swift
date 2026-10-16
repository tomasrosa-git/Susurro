import AppKit

@MainActor
enum TextInserter {
    private static let vKeyCode: CGKeyCode = 9

    /// Pasteboard + Cmd-V: works in every app, unlike synthesized typing which breaks on IMEs and long text.
    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
