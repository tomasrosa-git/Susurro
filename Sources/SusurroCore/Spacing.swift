public enum Spacing {
    private static let noSpaceAfter: Set<Character> = ["(", "[", "{", "¿", "¡", "\"", "'", "“", "‘", "«", "/", "@", "#"]
    private static let noSpaceBefore: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "…", "»", "”", "%"]

    /// Prefixes a space when the dictation lands right after a word, so consecutive dictations don't glue
    /// together ("Hola.Chau."). `previous` is the character before the cursor, nil if unknown or at the start.
    public static func join(_ text: String, after previous: Character?) -> String {
        guard let previous, let first = text.first else { return text }
        if previous.isWhitespace || noSpaceAfter.contains(previous) || noSpaceBefore.contains(first) {
            return text
        }
        return " " + text
    }
}
