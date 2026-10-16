import ApplicationServices

enum CursorContext {
    /// The character right before the insertion point in the focused text field, via Accessibility.
    /// Nil when the app doesn't expose it (many Electron and web views), which callers treat as "start of text".
    static func previousCharacter() -> Character? {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else { return nil }
        let focused = focusedRef as! AXUIElement

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
}
