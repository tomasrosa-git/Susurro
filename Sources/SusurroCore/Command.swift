import Foundation

/// Prompts and output checks for command mode: a spoken instruction applied to the selected text, or used to
/// write new text at the cursor when nothing is selected.
public enum Command {
    /// Qwen's output is capped at 1000 tokens on Groq's free tier; a longer selection can't come back whole.
    public static let maxSelectionLength = 2500

    private static let transformPrompt = """
        You edit text for the user. The user message contains the text they selected, between <selection> tags, \
        and a spoken instruction, between <instruction> tags. The instruction was transcribed from speech, so \
        ignore filler words and fix obvious transcription errors.

        Apply the instruction to the selection. Your output replaces the selection exactly as you write it, so:
        - Output only the resulting text: no preamble, no explanation, no surrounding quotes, no tags.
        - Change only what the instruction asks for. Keep the selection's language, register and regional forms \
        (voseo stays voseo) unless the instruction says otherwise.
        - Keep the selection's formatting (line breaks, lists, markdown or the lack of it).
        - If the instruction asks a question about the selection, still output replacement text, never an answer.
        """

    private static let generatePrompt = """
        You write text for the user. The user message contains a spoken instruction between <instruction> tags \
        asking you to write something: an email, a message, a reply, a list. It was transcribed from speech, so \
        ignore filler words and fix obvious transcription errors.

        Write that text. Your output is pasted where the user's cursor is, exactly as you write it, so:
        - Output only the requested text: no preamble, no explanation, no surrounding quotes, no tags.
        - Write in the instruction's language and variety unless it asks for another; if it is Rioplatense \
        Spanish (voseo), write with voseo.
        - Plain text, no markdown, unless the instruction asks for formatting.
        - Keep it as short as the request allows. Use only the facts the instruction gives: no extra reasons, \
        details or events. Keep its timing: in Spanish the present often means the future ("llego tarde el jueves" \
        is something that will happen), so don't turn it into the past. For a missing name or date the text \
        needs, leave a short placeholder in brackets.
        """

    public static func systemPrompt(hasSelection: Bool, terms: [String]) -> String {
        var prompt = hasSelection ? transformPrompt : generatePrompt
        if !terms.isEmpty {
            prompt += "\n- Spell these names and terms exactly like this: \(terms.joined(separator: ", "))."
        }
        return prompt
    }

    public static func userMessage(instruction: String, selection: String?) -> String {
        let instructionPart = "<instruction>\n\(instruction)\n</instruction>"
        guard let selection else { return instructionPart }
        return "<selection>\n\(selection)\n</selection>\n\n" + instructionPart
    }

    public static func maxTokens(selection: String?, model: String) -> Int {
        let estimate = (selection?.utf8.count ?? 0) / 3 * 2 + 400
        if model.hasPrefix("openai/gpt-oss") { return estimate + 512 }
        if model.hasPrefix("qwen/") { return min(estimate, 1000) }
        return estimate
    }

    /// Nil when nothing usable came back.
    public static func sanitize(_ output: String, selection: String?) -> String? {
        var text = output
            .replacingOccurrences(of: "</?(selection|instruction|output)>", with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = Cleanup.dropPreamble(text)
        text = dropWrappingFence(text, selection: selection)
        text = Cleanup.dropWrappingQuotes(text, raw: selection ?? "")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func dropWrappingFence(_ text: String, selection: String?) -> String {
        guard text.hasPrefix("```"), text.hasSuffix("```"), text.count > 6,
              selection?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") != true
        else { return text }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 3 else { return text }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n")
    }
}
