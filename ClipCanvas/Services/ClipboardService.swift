import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    static let accessEnabledKey = "settings.clipboardAccessEnabled"
    private static let duplicateReuseWindow: TimeInterval = 8 * 60
    private static var recentFingerprints: [String: Date] = [:]

    static var isAccessEnabled: Bool {
        UserDefaults.standard.bool(forKey: accessEnabledKey)
    }

    static func readContent() -> ClipboardContent? {
        #if canImport(UIKit)
        let pb = UIPasteboard.general
        if let image = pb.image, let data = image.pngData() {
            return .image(data, uti: "public.png")
        }
        if let text = pb.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        #elseif canImport(AppKit)
        let pb = NSPasteboard.general
        if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            return .image(data, uti: pb.data(forType: .png) == nil ? "public.tiff" : "public.png")
        }
        if let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        #endif
        return nil
    }

    static func write(clip: Clip) {
        #if canImport(UIKit)
        if clip.type == .image, let data = clip.imageData, let image = UIImage(data: data) {
            UIPasteboard.general.image = image
        } else {
            UIPasteboard.general.string = clip.content
        }
        #elseif canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        if clip.type == .image, let data = clip.imageData {
            pb.setData(data, forType: clip.imageUTI == "public.tiff" ? .tiff : .png)
        } else {
            pb.setString(clip.content, forType: .string)
        }
        #endif
    }

    static func writeString(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        #endif
    }

    static func markImported(_ content: ClipboardContent, at date: Date = Date()) {
        recentFingerprints[content.historyFingerprint] = date
        recentFingerprints = recentFingerprints.filter { date.timeIntervalSince($0.value) < duplicateReuseWindow }
    }

    static func wasRecentlyImported(_ content: ClipboardContent, at date: Date = Date()) -> Bool {
        guard let last = recentFingerprints[content.historyFingerprint] else { return false }
        return date.timeIntervalSince(last) < duplicateReuseWindow
    }
}

// Factory extension — one canonical way to create a Clip from clipboard content
extension Clip {
    static func make(from content: ClipboardContent, origin: ClipOrigin) -> Clip {
        switch content {
        case .text(let text):
            let body = text.trimmedClipboardContent
            let classification = ClipClassificationService.classifySensitivity(body)
            return Clip(
                content: body,
                origin: origin,
                sensitivity: classification.sensitivity,
                sensitivityReason: classification.reason
            )
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
            let fingerprint = text.normalizedClipboardHistoryText
            let existing = try? context.fetch(
                FetchDescriptor<Clip>(
                    predicate: #Predicate { $0.deletedAt == nil }
                )
            )
            if let first = existing?.first(where: { $0.type != .image && $0.content.normalizedClipboardHistoryText == fingerprint }) {
                ClipboardService.markImported(content)
                return (first, false)
            }
        case .image(let data, _):
            let existing = try? context.fetch(
                FetchDescriptor<Clip>(
                    predicate: #Predicate { $0.deletedAt == nil }
                )
            )
            if let first = existing?.first(where: { $0.type == .image && $0.imageData == data }) {
                ClipboardService.markImported(content)
                return (first, false)
            }
        }

        ClipboardService.markImported(content)
        return (Clip.make(from: content, origin: origin), true)
    }
}

private extension ClipboardContent {
    var historyFingerprint: String {
        switch self {
        case .text(let text):
            return "text:\(text.normalizedClipboardHistoryText.lowercased())"
        case .image(let data, _):
            return "image:\(data.count):\(data.hashValue)"
        }
    }
}

private extension String {
    var trimmedClipboardContent: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? self : trimmed
    }

    var normalizedClipboardHistoryText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
