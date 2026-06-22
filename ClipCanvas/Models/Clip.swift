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

enum SensitivityReason: String, Codable, CaseIterable {
    case passwordLike
    case secretKeyword
    case creditCard
    case ssn
    case email
    case userMarkedPrivate
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
final class Clip: SoftDeletable, Identifiable {
    var id: UUID = UUID()
    var content: String
    var imageData: Data?
    var imageUTI: String?
    var type: ClipType
    var origin: ClipOrigin
    var sensitivity: Sensitivity
    var sensitivityReasonRaw: String?
    var expiresAt: Date?
    var color: CardColor
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

    @Relationship(deleteRule: .nullify, inverse: \CanvasObject.clip)
    var canvasObjects: [CanvasObject] = []

    @Relationship(deleteRule: .nullify)
    var tags: [ClipTag] = []

    init(
        content: String,
        imageData: Data? = nil,
        imageUTI: String? = nil,
        origin: ClipOrigin,
        sensitivity: Sensitivity = .normal,
        sensitivityReason: SensitivityReason? = nil,
        color: CardColor = .cloud
    ) {
        let now = Date()
        self.content = content
        self.imageData = imageData
        self.imageUTI = imageUTI
        self.origin = origin
        self.sensitivity = sensitivity
        self.sensitivityReasonRaw = sensitivityReason?.rawValue
        self.expiresAt = nil
        self.color = color
        self.createdAt = now
        self.updatedAt = now
        self.type = Self.detect(content: content, imageData: imageData)
    }

    var isPrivateContent: Bool { sensitivity == .privateContent }

    var isMasked: Bool { isPrivateContent }

    var sensitivityReason: SensitivityReason? {
        get {
            guard let sensitivityReasonRaw else { return nil }
            return SensitivityReason(rawValue: sensitivityReasonRaw)
        }
        set {
            sensitivityReasonRaw = newValue?.rawValue
        }
    }

    var preview: String {
        if type == .image { return content.isEmpty ? "Image" : content }
        return sensitiveMarkdownContent
    }

    var maskedPreview: String {
        SensitiveClipDisplay.mask(for: content)
    }

    func displayPreview(isRevealed: Bool) -> String {
        if type == .image { return content.isEmpty ? "Image" : content }
        return sensitiveMarkdownContent
    }

    var sensitiveMarkdownContent: String {
        guard type != .image else { return content }
        guard isPrivateContent else { return content }
        return ClipClassificationService.markSensitiveMarkdown(in: content)
    }

    func softDelete() {
        deletedAt = Date()
        isPinned = false
    }

    func updateSensitivity(
        _ newSensitivity: Sensitivity,
        reason: SensitivityReason? = nil,
        at date: Date = Date()
    ) {
        sensitivity = newSensitivity
        sensitivityReason = reason
        if newSensitivity != .privateContent {
            expiresAt = nil
        }
    }

    func markPrivate(at date: Date = Date()) {
        updateSensitivity(.privateContent, reason: .userMarkedPrivate, at: date)
    }

    func unmarkPrivate() {
        updateSensitivity(.normal, reason: nil)
    }

    func duplicateForCanvas(origin: ClipOrigin? = nil) -> Clip {
        let copy = Clip(
            content: content,
            imageData: imageData,
            imageUTI: imageUTI,
            origin: origin ?? self.origin,
            sensitivity: sensitivity,
            sensitivityReason: sensitivityReason,
            color: color
        )
        copy.expiresAt = expiresAt
        copy.isPinned = false
        copy.tags = tags
        return copy
    }

    // MARK: - Type detection

    static func detect(content: String, imageData: Data?) -> ClipType {
        ClipClassificationService.detectType(content: content, imageData: imageData)
    }
}
