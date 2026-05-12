import Foundation
import SwiftData

// MARK: - Supporting enums

enum ClipType: String, Codable, CaseIterable {
    case text, url, code, image

    var icon: String {
        switch self {
        case .text:  return "doc.text"
        case .url:   return "link"
        case .code:  return "curlybraces"
        case .image: return "photo"
        }
    }
}

enum ClipOrigin: String, Codable, CaseIterable {
    case clipboard  // captured automatically or via paste
    case typed      // user typed directly in app
    case shared     // received via Share sheet

    var label: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .typed:     return "Typed"
        case .shared:    return "Shared"
        }
    }
}

enum Sensitivity: String, Codable {
    case normal
    case sensitive       // PII (email, SSN, credit card)
    case privateContent  // secrets (password, api_key, token)
}

enum CardColor: String, Codable, CaseIterable {
    case cloud, banana, flamingo, sage, sky, lavender, peach

    var label: String {
        switch self {
        case .cloud:    return "Cloud"
        case .banana:   return "Banana"
        case .flamingo: return "Flamingo"
        case .sage:     return "Sage"
        case .sky:      return "Sky"
        case .lavender: return "Lavender"
        case .peach:    return "Peach"
        }
    }
}

// MARK: - Model

@Model
final class Clip {
    var id: UUID = UUID()
    var content: String
    var imageData: Data?
    var imageUTI: String?
    var type: ClipType
    var origin: ClipOrigin
    var sensitivity: Sensitivity
    var color: CardColor
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Cascade-delete all canvas placements when this clip is removed
    @Relationship(deleteRule: .cascade, inverse: \CanvasPlacement.clip)
    var placements: [CanvasPlacement] = []

    init(
        content: String,
        imageData: Data? = nil,
        imageUTI: String? = nil,
        origin: ClipOrigin,
        sensitivity: Sensitivity = .normal,
        color: CardColor = .cloud
    ) {
        self.content = content
        self.imageData = imageData
        self.imageUTI = imageUTI
        self.origin = origin
        self.sensitivity = sensitivity
        self.color = color
        self.type = Self.detect(content: content, imageData: imageData)
    }

    var isMasked: Bool { sensitivity != .normal }

    var preview: String {
        guard !isMasked else {
            return String(repeating: "•", count: min(max(content.count, 6), 24))
        }
        if type == .image { return content.isEmpty ? "Image" : content }
        return content
    }

    // MARK: - Type detection

    static func detect(content: String, imageData: Data?) -> ClipType {
        if imageData != nil { return .image }
        if looksLikeURL(content) { return .url }
        if looksLikeCode(content) { return .code }
        return .text
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        guard let url = URL(string: text) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return false }
        let keywords = [
            "func ", "class ", "struct ", "enum ", "import ",
            "def ", "async ", "function ", "const ", "public ",
            "private ", "#include", "SELECT ", "->", "=>"
        ]
        let hits = keywords.filter { text.contains($0) }.count
        let hasIndent = lines.dropFirst().contains { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        return hits >= 2 || (hits >= 1 && hasIndent)
    }
}
