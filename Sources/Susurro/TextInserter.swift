import AppKit

@MainActor
enum TextInserter {
    private static let vKeyCode: CGKeyCode = 9
    private static let cKeyCode: CGKeyCode = 8
    /// The target app reads the pasteboard when it handles ⌘V, asynchronously; restoring sooner can paste
    /// the old contents instead.
    private static let restoreDelay: TimeInterval = 0.5
    /// nspasteboard.org convention: clipboard managers skip items marked transient.
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    /// Pasteboard + Cmd-V: works in every app, unlike synthesized typing which breaks on IMEs and long text.
    static func insert(_ text: String, restoringClipboard: Bool) {
        let pasteboard = NSPasteboard.general
        let previous = restoringClipboard ? snapshot(pasteboard) : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if restoringClipboard { pasteboard.setData(Data(), forType: transientType) }
        let ours = pasteboard.changeCount
        postCommandShortcut(vKeyCode)

        guard let previous else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            // Something else copied in the meantime; that is newer than what we saved.
            guard pasteboard.changeCount == ours else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects(previous)
        }
    }

    /// For apps that don't expose the selection through Accessibility: ⌘C, read it, put the old clipboard back.
    /// Nil when the copy didn't change the clipboard, which means nothing was selected.
    static func copySelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        let before = pasteboard.changeCount
        postCommandShortcut(cKeyCode)
        for _ in 0..<20 where pasteboard.changeCount == before {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard pasteboard.changeCount != before else { return nil }
        let text = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects(saved)
        return text?.isEmpty == false ? text : nil
    }

    private static func postCommandShortcut(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }
}
