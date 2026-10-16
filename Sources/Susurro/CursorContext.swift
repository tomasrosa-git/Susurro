import ApplicationServices

@MainActor
enum CursorContext {
    /// The character right before the insertion point in the focused text field, via Accessibility.
    /// Nil when the app doesn't expose it (many Electron and web views), which callers treat as "start of text".
    static func previousCharacter() -> Character? {
        guard let focused = focusedElement() else { return nil }
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID()
        else { return nil }
        var selection = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &selection), selection.location > 0 else { return nil }

        var previous = CFRange(location: selection.location - 1, length: 1)
        guard let previousRange = AXValueCreate(.cfRange, &previous) else { return nil }
        var textRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused, kAXStringForRangeParameterizedAttribute as CFString, previousRange, &textRef
        ) == .success, let text = textRef as? String else { return nil }
        return text.last
    }

    /// The selected text, nil when nothing is selected. Accessibility first; apps that don't expose it get a ⌘C.
    static func selectedText() async -> String? {
        if let focused = focusedElement() {
            var textRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &textRef) == .success,
               let text = textRef as? String {
                // An empty answer is trusted: ⌘C with no selection copies the whole line in some editors.
                return text.isEmpty ? nil : text
            }
        }
        return await TextInserter.copySelection()
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else { return nil }
        return (focusedRef as! AXUIElement)
    }
}
