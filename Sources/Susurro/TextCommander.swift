import Foundation
import SusurroCore

/// Command mode: applies a spoken instruction to the selection, or writes new text when there is none.
struct TextCommander: Sendable {
    enum CommandError: LocalizedError {
        case selectionTooLong
        case truncated
        case emptyReply

        var errorDescription: String? {
            switch self {
            case .selectionTooLong: "La selección es demasiado larga para el modo comando (máx. \(Command.maxSelectionLength) caracteres)."
            case .truncated: "La respuesta quedó cortada; probá con menos texto."
            case .emptyReply: "El modo comando no devolvió texto."
            }
        }
    }

    let apiKey: String
    let model: String
    let terms: [String]

    /// Longer than cleanup's: here there is no raw text to fall back to.
    private static let timeout: TimeInterval = 20

    func run(instruction: String, selection: String?) async throws -> String {
        if let selection, selection.count > Command.maxSelectionLength { throw CommandError.selectionTooLong }
        guard let reply = try await GroqChat.complete(
            apiKey: apiKey,
            model: model,
            system: Command.systemPrompt(hasSelection: selection != nil, terms: terms),
            user: Command.userMessage(instruction: instruction, selection: selection),
            maxTokens: Command.maxTokens(selection: selection, model: model),
            timeout: Self.timeout
        ) else { throw CommandError.emptyReply }
        if reply.truncated { throw CommandError.truncated }
        guard let text = Command.sanitize(reply.content, selection: selection) else { throw CommandError.emptyReply }
        return text
    }
}
