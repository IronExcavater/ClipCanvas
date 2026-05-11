import Foundation
import SwiftData

enum SnippetType: String, Codable, CaseIterable {
    case text
    case url
    case code
    case image

    var icon: String {
        switch self {
        case .text: "doc.text"
        case .url: "link"
        case .code: "curlybraces"
        case .image: "photo"
        }
    }
}

enum Sensitivity: String, Codable, CaseIterable {
    case normal
    case sensitive       // regex-matched PII (SSN, credit card, email)
    case privateContent  // keyword-matched secrets (password, token, api_key)
}

// Records where a snippet came from. Used for UI labels and to distinguish
// user-added cards from generated transform results.
enum CaptureMethod: String, Codable, CaseIterable {
    case manualPaste    // user pressed the Paste button
    case quickAction    // auto-captured by the clipboard watcher
    case appIntent      // added via Siri/Shortcuts
    case transformResult // created by an AI transform

    var label: String {
        switch self {
        case .manualPaste: "Paste"
        case .quickAction: "Quick Action"
        case .appIntent: "Shortcut"
        case .transformResult: "Transform"
        }
    }
}

// @Model marks this class for SwiftData persistence — each instance is a row in SQLite.
@Model
final class Snippet {
    var id: UUID
    var text: String
    var imageData: Data?    // nil for text snippets; stores raw PNG bytes for image snippets
    var imageUTI: String?   // Uniform Type Identifier, e.g. "public.png" — identifies the image format
    var type: SnippetType
    var sensitivity: Sensitivity
    var captureMethod: CaptureMethod
    var createdAt: Date
    var expiresAt: Date?    // nil means the snippet never expires
    var isPinned: Bool

    init(
        text: String,
        imageData: Data? = nil,
        imageUTI: String? = nil,
        type: SnippetType = .text,
        sensitivity: Sensitivity = .normal,
        captureMethod: CaptureMethod = .manualPaste,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.text = text
        self.imageData = imageData
        self.imageUTI = imageUTI
        self.type = type
        self.sensitivity = sensitivity
        self.captureMethod = captureMethod
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isPinned = isPinned
    }
}

extension Snippet {
    // Factory method — the canonical way to create a Snippet from a text string.
    // Runs sensitivity detection and sets an expiry date based on the result.
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

    // Factory method for clipboard content — handles both text and image cases.
    // All clipboard-to-model conversion goes through here so expiry, sensitivity,
    // and type detection stay consistent across the app.
    static func make(from content: PasteboardContent, capturedBy method: CaptureMethod) -> Snippet {
        switch content {
        case .text(let text):
            return make(from: text, capturedBy: method)
        case .image(let data, let uti):
            let snippet = Snippet(
                text: "Image from clipboard",
                imageData: data,
                imageUTI: uti,
                type: .image,
                sensitivity: .normal,
                captureMethod: method
            )
            ExpiryService.setExpiry(for: snippet)
            return snippet
        }
    }

    // Lightweight heuristic to classify text content. Only affects presentation —
    // the original clipboard content is always stored verbatim.
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

    var isMasked: Bool { sensitivity != .normal }

    var preview: String {
        // Show a bullet placeholder for sensitive content in the UI, but keep the
        // original text stored so copying and transforms use the real value.
        if type == .image { return text.isEmpty ? "Image" : text }
        return isMasked ? String(repeating: "•", count: min(max(text.count, 6), 24)) : text
    }

    var dragText: String {
        if type == .image { return text.isEmpty ? "Image from ClipCanvas" : text }
        return text
    }

    var defaultCardSize: (width: Double, height: Double) {
        switch type {
        case .code: (280, 190)
        case .image: (260, 210)
        case .text, .url: (240, 160)
        }
    }
}
