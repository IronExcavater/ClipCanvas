import SwiftData
import UIKit

// A value representing what's on the clipboard right now
enum ClipboardContent {
    case text(String)
    case image(Data, uti: String)

    // Used to detect when clipboard changes without storing the full content
    var fingerprint: String {
        switch self {
        case .text(let s):     return "t:\(s.hashValue)"
        case .image(let d, _): return "i:\(d.count):\(d.hashValue)"
        }
    }
}

enum ClipboardService {

    static func readContent() -> ClipboardContent? {
        let pb = UIPasteboard.general
        if let image = pb.image, let data = image.pngData() {
            return .image(data, uti: "public.png")
        }
        if let text = pb.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        return nil
    }

    static func write(clip: Clip) {
        if clip.type == .image, let data = clip.imageData, let image = UIImage(data: data) {
            UIPasteboard.general.image = image
        } else {
            UIPasteboard.general.string = clip.content
        }
    }

    static func writeString(_ string: String) {
        UIPasteboard.general.string = string
    }
}

// Factory extension — one canonical way to create a Clip from clipboard content
extension Clip {
    static func make(from content: ClipboardContent, origin: ClipOrigin) -> Clip {
        switch content {
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = trimmed.isEmpty ? text : trimmed
            let sensitivity = SensitivityService.detect(body)
            return Clip(content: body, origin: origin, sensitivity: sensitivity)
        case .image(let data, let uti):
            return Clip(content: "", imageData: data, imageUTI: uti, origin: origin)
        }
    }

    static func findOrMake(
        from content: ClipboardContent,
        origin: ClipOrigin,
        in context: ModelContext
    ) -> (clip: Clip, isNew: Bool) {
        switch content {
        case .text(let text):
            let fingerprint = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let existing = try? context.fetch(
                FetchDescriptor<Clip>(
                    predicate: #Predicate { $0.content == fingerprint && $0.deletedAt == nil }
                )
            )
            if let first = existing?.first {
                first.updatedAt = Date()
                return (first, false)
            }
        case .image:
            break
        }

        return (Clip.make(from: content, origin: origin), true)
    }
}
