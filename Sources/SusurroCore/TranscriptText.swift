import Foundation

public enum TranscriptText {
    /// Joins whisper's per-segment lines and drops its non-speech markers like [BLANK_AUDIO] or [Music].
    public static func normalize(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"\[[^\]]*\]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
