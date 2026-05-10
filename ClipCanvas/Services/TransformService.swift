import Foundation

struct TransformService {
    static func perform(
        _ kind: TransformKind,
        on text: String
    ) async throws -> String {
        let cleaned = normalize(text)
        switch kind {
        case .distill:
            return distill(cleaned)
        case .actionItems:
            return actionItems(cleaned)
        case .cleanUp:
            return cleaned
        case .rewrite:
            return rewrite(cleaned)
        case .title:
            return title(for: cleaned)
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

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

    private static func actionItems(_ text: String) -> String {
        let markers = ["task", "follow up", "send", "book", "call", "email", "review", "fix", "update", "create"]
        let lines = text.components(separatedBy: .newlines)
        let matches = lines.filter { line in
            let lowercased = line.lowercased()
            return markers.contains { lowercased.contains($0) }
        }
        let items = matches.isEmpty ? lines.prefix(5).map(String.init) : matches
        return items
            .map { "- [ ] \($0.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")
    }

    private static func rewrite(_ text: String) -> String {
        text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func title(for text: String) -> String {
        let words = text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
            .prefix(8)
        return words.joined(separator: " ")
    }
}
