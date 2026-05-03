import Foundation
import SwiftData

enum SnippetType: String, Codable, CaseIterable {
    case text
    case url
    case code

    var icon: String {
        switch self {
        case .text: "doc.text"
        case .url: "link"
        case .code: "curlybraces"
        }
    }
}

enum Sensitivity: String, Codable, CaseIterable {
    case normal
    case sensitive
    case privateContent
}

enum CaptureMethod: String, Codable, CaseIterable {
    case manualPaste
    case quickAction
    case appIntent
    case transformResult

    var label: String {
        switch self {
        case .manualPaste: "Paste"
        case .quickAction: "Quick Action"
        case .appIntent: "Shortcut"
        case .transformResult: "Transform"
        }
    }
}

@Model
final class Snippet {
    var id: UUID
    var text: String
    var type: SnippetType
    var sensitivity: Sensitivity
    var captureMethod: CaptureMethod
    var createdAt: Date
    var expiresAt: Date?
    var isPinned: Bool

    init(
        text: String,
        type: SnippetType = .text,
        sensitivity: Sensitivity = .normal,
        captureMethod: CaptureMethod = .manualPaste,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.text = text
        self.type = type
        self.sensitivity = sensitivity
        self.captureMethod = captureMethod
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isPinned = isPinned
    }
}

extension Snippet {
    static func make(from text: String, capturedBy method: CaptureMethod) -> Snippet {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sensitivity = SensitivityDetector.detect(for: text)
        let snippet = Snippet(
            text: trimmed.isEmpty ? text : trimmed,
            type: detectType(for: trimmed),
            sensitivity: sensitivity,
            captureMethod: method
        )
        ExpiryService.setExpiry(for: snippet)
        return snippet
    }

    static func detectType(for text: String) -> SnippetType {
        if let url = URL(string: text), url.scheme == "https" || url.scheme == "http" {
            return .url
        }

        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return .text }

        let keywords = [
            "func ", "class ", "struct ", "enum ", "import ", "def ", "async ",
            "function ", "const ", "public ", "private ", "#include", "SELECT ",
            "FROM ", "INSERT ", "->", "=>", "{}"
        ]
        let hits = keywords.filter { text.contains($0) }.count
        let indented = lines.dropFirst().contains { $0.hasPrefix("  ") || $0.hasPrefix("\t") }

        if hits >= 2 || (hits >= 1 && indented) { return .code }
        if (text.hasPrefix("{") && text.hasSuffix("}")) || (text.hasPrefix("[") && text.hasSuffix("]")) {
            return .code
        }
        return .text
    }

    var isMasked: Bool {
        sensitivity != .normal
    }

    var preview: String {
        isMasked ? String(repeating: "•", count: min(max(text.count, 6), 24)) : text
    }
}
