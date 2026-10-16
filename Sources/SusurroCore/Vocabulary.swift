import Foundation

/// The user's dictionary: terms that steer transcription and cleanup, plus fixed replacements for words the
/// transcriber keeps getting wrong the same way.
public struct Vocabulary: Equatable, Sendable {
    public struct Replacement: Equatable, Sendable {
        public let heard: String
        public let written: String
    }

    public private(set) var terms: [String] = []
    public private(set) var replacements: [Replacement] = []

    public static let empty = Vocabulary()

    public static let template = """
        # Diccionario de Susurro
        #
        # Una línea por término: nombres propios, marcas o palabras técnicas que querés que se escriban así.
        #   Queleo
        #   Prisma
        #
        # Para corregir algo que se transcribe mal siempre igual: lo que sale -> lo que querés.
        #   que leo -> Queleo
        #
        # No distingue mayúsculas ni tildes y solo reemplaza palabras completas.
        # Después de guardar, usá "Recargar configuración" en el menú.

        """

    public var isEmpty: Bool { terms.isEmpty }

    public static func parse(_ text: String) -> Vocabulary {
        var vocabulary = Vocabulary()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if let arrow = line.range(of: "->") {
                let heard = line[..<arrow.lowerBound].trimmingCharacters(in: .whitespaces)
                let written = line[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
                guard !heard.isEmpty, !written.isEmpty else { continue }
                vocabulary.replacements.append(Replacement(heard: heard, written: written))
                vocabulary.addTerm(written)
            } else {
                vocabulary.addTerm(line)
            }
        }
        return vocabulary
    }

    private mutating func addTerm(_ term: String) {
        if !terms.contains(term) { terms.append(term) }
    }

    /// Whisper treats its prompt as preceding text, so a plain list nudges spelling without being transcribed.
    public var whisperPrompt: String? {
        isEmpty ? nil : terms.joined(separator: ", ") + "."
    }

    public func apply(to text: String) -> String {
        replacements.reduce(text) { Self.replace($1, in: $0) }
    }

    private static func replace(_ replacement: Replacement, in text: String) -> String {
        var result = ""
        var cursor = text.startIndex
        var searchFrom = text.startIndex
        while let match = text.range(
            of: replacement.heard,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchFrom..<text.endIndex
        ) {
            // A match inside a longer word only advances one character, so an overlapping whole-word match
            // right after it isn't skipped.
            searchFrom = text.index(after: match.lowerBound)
            guard isBoundary(before: match.lowerBound, in: text), isBoundary(after: match.upperBound, in: text)
            else { continue }
            result += text[cursor..<match.lowerBound]
            result += replacement.written
            cursor = match.upperBound
            searchFrom = match.upperBound
        }
        return result + text[cursor...]
    }

    private static func isBoundary(before index: String.Index, in text: String) -> Bool {
        index == text.startIndex || !isWordCharacter(text[text.index(before: index)])
    }

    private static func isBoundary(after index: String.Index, in text: String) -> Bool {
        index == text.endIndex || !isWordCharacter(text[index])
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
