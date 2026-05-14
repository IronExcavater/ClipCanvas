import Foundation

enum WorkspaceNamePolicy {
    nonisolated static let maximumLength = 48
    nonisolated static let fallbackName = "Untitled"

    nonisolated static func normalized(_ rawName: String, fallback: String = fallbackName) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let resolved = collapsed.isEmpty ? fallback : collapsed
        return String(resolved.prefix(maximumLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func limitedEditingText(_ rawName: String) -> String {
        String(rawName.prefix(maximumLength))
    }
}
