import Foundation
import FoundationModels  // Apple's on-device language model framework (requires Apple Intelligence)

struct TransformService {
    static func perform(
        _ kind: TransformKind,
        on text: String
    ) async throws -> String {
        let cleaned = normalize(text)
        // Use Apple Intelligence if it's available on this device; otherwise fall back
        // to simple heuristics so the feature still works on older hardware.
        if SystemLanguageModel.default.isAvailable {
            return try await AppleIntelligenceService.perform(kind, on: cleaned)
        }

        switch kind {
        case .distill:    return distill(cleaned)
        case .actionItems: return actionItems(cleaned)
        case .cleanUp:    return cleaned    // without a model, normalisation is the best we can do
        case .rewrite:    return rewrite(cleaned)
        case .title:      return title(for: cleaned)
        }
    }

    // Strips blank lines and trims whitespace from each line before sending to a model.
    private static func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    // Fallback distill: splits on newlines or sentence boundaries and takes the first 6 items.
    private static func distill(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let source = lines.count > 1 ? lines : text.components(separatedBy: ". ")
        return source
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(6)
            .map { "- \($0)" }
            .joined(separator: "\n")
    }

    // Fallback action items: looks for lines containing task-related verbs.
    private static func actionItems(_ text: String) -> String {
        let markers = ["task", "follow up", "send", "book", "call", "email", "review", "fix", "update", "create"]
        let lines = text.components(separatedBy: .newlines)
        let matches = lines.filter { line in
            let lowercased = line.lowercased()
            return markers.contains { lowercased.contains($0) }
        }
        let items: [String] = matches.isEmpty ? Array(lines.prefix(5)) : matches
        return items
            .map { "- [ ] \($0.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")
    }

    // Fallback rewrite: collapses double spaces and trims whitespace.
    private static func rewrite(_ text: String) -> String {
        text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Fallback title: takes the first 8 non-punctuation words.
    private static func title(for text: String) -> String {
        text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
            .prefix(8)
            .joined(separator: " ")
    }
}

private enum AppleIntelligenceService {
    static func perform(_ kind: TransformKind, on text: String) async throws -> String {
        // LanguageModelSession manages a single conversation with the on-device model.
        // `instructions` act as a system prompt that sets the model's behaviour.
        let session = LanguageModelSession(
            instructions: "You rewrite clipboard snippets for a compact canvas app. Return only the result."
        )
        let response = try await session.respond(to: prompt(for: kind, text: text))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func prompt(for kind: TransformKind, text: String) -> String {
        switch kind {
        case .distill:
            "Distill this into at most five concise bullets:\n\n\(text)"
        case .actionItems:
            "Extract concrete action items as a checklist. Keep only actionable work:\n\n\(text)"
        case .cleanUp:
            "Clean up spacing, grammar, and formatting without changing meaning:\n\n\(text)"
        case .rewrite:
            "Rewrite this clearly and concisely:\n\n\(text)"
        case .title:
            "Create a short title, eight words or fewer:\n\n\(text)"
        }
    }
}
