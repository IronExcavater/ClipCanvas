import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ClipActionService {
    static func copy(_ clip: Clip) {
        ClipboardService.write(clip: clip)
    }

    static func copy(_ clips: [Clip]) {
        if let only = clips.first, clips.count == 1 {
            copy(only)
            return
        }
        let text = clips.map(\.content).filter { !$0.isEmpty }.joined(separator: "\n\n")
        guard !text.isEmpty else { return }
        ClipboardService.writeString(text)
    }

    static func togglePin(_ clip: Clip) {
        clip.isPinned.toggle()
    }

    static func softDelete(_ clip: Clip) {
        clip.softDelete()
    }

    static func toggleSensitive(_ clip: Clip) {
        if clip.isPrivateContent {
            let unmarked = removeSensitiveMarkdown(from: clip.content)
            clip.content = unmarked
            clip.updateSensitivity(.normal, reason: nil)
        } else {
            let marked = ClipClassificationService.markSensitiveMarkdown(in: clip.content)
            clip.content = marked
            let classification = ClipClassificationService.classifySensitivity(marked)
            clip.updateSensitivity(classification.sensitivity, reason: classification.reason)
        }
        clip.updatedAt = Date()
    }

    @MainActor
    static func clearHistory(_ clips: [Clip]) {
        clips.forEach(softDelete)
    }

    @MainActor
    static func openURL(for clip: Clip) {
        guard let url = openableURL(for: clip) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    static func openableURL(for clip: Clip) -> URL? {
        guard clip.type == .url || clip.content.localizedCaseInsensitiveContains("http") || clip.content.localizedCaseInsensitiveContains("www.") else {
            return nil
        }
        return firstURL(in: clip.content)
    }

    private static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        guard let match = detector?.firstMatch(in: text, options: [], range: range),
              let matchedRange = Range(match.range, in: text) else {
            return normalizedURL(from: text)
        }
        return normalizedURL(from: String(text[matchedRange]))
    }

    private static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.lowercased().hasPrefix("www.") ? "https://\(trimmed)" : trimmed
        guard let url = URL(string: candidate), url.host != nil else { return nil }
        return url
    }

    private static func removeSensitiveMarkdown(from text: String) -> String {
        let regex = try? NSRegularExpression(pattern: #"\|\|(.+?)\|\|"#)
        let range = NSRange(text.startIndex..., in: text)
        return regex?.stringByReplacingMatches(in: text, range: range, withTemplate: "$1") ?? text
    }
}
