import Foundation

nonisolated enum TextTransformFallbacks {
    static func text(for skillID: String, input: String) -> String? {
        switch skillID {
        case "clip.cleanUp":
            return collapseWhitespace(input)
        case "clip.distill":
            return distilled(input)
        case "clip.actionItems":
            return actionItems(input)
        case "clip.rewrite":
            return collapseWhitespace(input)
        case "clip.title":
            return title(input)
        default:
            return nil
        }
    }

    static func suggestedTags(for text: String) -> [String] {
        let lower = text.lowercased()
        var tags: [String] = []
        if lower.contains("http://") || lower.contains("https://") { tags.append("Link") }
        if lower.contains("swift") || lower.contains("swiftdata") || lower.contains("swiftui") { tags.append("Swift") }
        if lower.contains("todo") || lower.contains("action") { tags.append("Action") }
        if tags.isEmpty { tags.append("Note") }
        return tags
    }

    static func collapseWhitespace(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func distilled(_ text: String) -> String {
        let cleaned = collapseWhitespace(text)
        let sentenceEnd = cleaned.firstIndex(where: { ".!?".contains($0) })
        if let sentenceEnd {
            return String(cleaned[...sentenceEnd])
        }
        return String(cleaned.prefix(180))
    }

    private static func actionItems(_ text: String) -> String {
        let clauses = text
            .components(separatedBy: CharacterSet(charactersIn: ".\n"))
            .map { collapseWhitespace($0) }
            .filter { !$0.isEmpty }
        return clauses.prefix(5).map { "- \($0)" }.joined(separator: "\n")
    }

    private static func title(_ text: String) -> String {
        let words = collapseWhitespace(text)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let stopWords = Set(["for", "to", "and", "or", "of", "the", "a", "an"])
        var titleWords = Array(words.prefix(5))
        while let last = titleWords.last?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,:;")),
              stopWords.contains(last) {
            titleWords.removeLast()
        }
        return titleWords.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ".,:;"))
    }
}
