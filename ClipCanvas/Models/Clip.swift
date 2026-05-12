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
final class Clip: SoftDeletable {
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
    var deletedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \CanvasPlacement.clip)
    var placements: [CanvasPlacement] = []

    @Relationship(deleteRule: .nullify)
    var tags: [ClipTag] = []

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

    func softDelete() {
        deletedAt = Date()
        isPinned = false
    }

    // MARK: - Type detection

    static func detect(content: String, imageData: Data?) -> ClipType {
        if imageData != nil { return .image }
        if looksLikeURL(content) { return .url }
        if looksLikeCode(content) { return .code }
        return .text
    }

    // Pre-compiled patterns
    private static let urlPrefixRegex = try! NSRegularExpression(
        pattern: #"^(?:https?://|www\.)\S"#,
        options: .caseInsensitive
    )
    private static let codeKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:func|class|struct|enum|import|def|async|function|const|interface|extends|implements|public|private|protected|static|return|override|void|#include|#import|SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|ALTER)\b"#
    )
    private static let codeOperatorRegex = try! NSRegularExpression(
        pattern: #"(?:->|=>|::|===|!==|\?\?|&&|\|\||\+=|-=|\*=|/=)"#
    )

    private static func looksLikeURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n"), (4...2048).contains(trimmed.count) else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard urlPrefixRegex.firstMatch(in: trimmed, range: range) != nil else { return false }
        let candidate = trimmed.lowercased().hasPrefix("www.") ? "https://\(trimmed)" : trimmed
        guard let url = URL(string: candidate), let host = url.host else { return false }
        return host.contains(".")
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return false }
        let range = NSRange(text.startIndex..., in: text)
        let keywords = codeKeywordRegex.numberOfMatches(in: text, range: range)
        let operators = codeOperatorRegex.numberOfMatches(in: text, range: range)
        let braces = text.filter { "{}[]".contains($0) }.count
        let hasIndent = lines.dropFirst().contains { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        let semicolons = text.filter { $0 == ";" }.count

        var score = 0
        score += min(keywords, 3)
        score += min(operators, 2)
        score += braces >= 4 ? 2 : braces >= 2 ? 1 : 0
        if hasIndent { score += 1 }
        if semicolons >= 2 { score += 1 }
        return score >= 3
    }
}
