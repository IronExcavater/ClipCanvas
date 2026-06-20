import SwiftUI

struct MarkdownPreview: View {
    let text: String
    var emptyText = " "
    private static let orderedListPattern = try? NSRegularExpression(pattern: #"^\d+\.\s+"#)

    var body: some View {
        let blocks = Self.blocks(for: text, emptyText: emptyText)
        if blocks.count == 1, case .paragraph(let content) = blocks[0].kind {
            Text(Self.attributedString(for: content, emptyText: emptyText))
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(blocks) { block in
                    switch block.kind {
                    case .paragraph(let content):
                        Text(Self.attributedString(for: content, emptyText: emptyText))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .bullet(let content, let level):
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("•")
                                .fontWeight(.semibold)
                                .frame(width: 10, alignment: .center)
                            Text(Self.attributedString(for: content, emptyText: emptyText))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, CGFloat(level) * 16)
                    case .empty:
                        Text(" ")
                    }
                }
            }
        }
    }

    static func attributedString(for text: String, emptyText: String = " ") -> AttributedString {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyText : text
        return MarkdownInlineRenderer.attributedString(for: source)
    }

    static func blocks(for text: String, emptyText: String = " ") -> [MarkdownPreviewBlock] {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyText : text
        let lines = source.components(separatedBy: .newlines)
        return lines.enumerated().map { index, line in
            let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let trimmedNS = trimmed as NSString
            if trimmed.isEmpty {
                return MarkdownPreviewBlock(index: index, kind: .empty)
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let body = (trimmed as NSString).substring(from: 2)
                return MarkdownPreviewBlock(
                    index: index,
                    kind: .bullet(body, level: min(leadingWhitespace / 2, 3))
                )
            }
            if let match = Self.orderedListPattern?.firstMatch(
                in: trimmed,
                range: NSRange(location: 0, length: trimmedNS.length)
            ), match.range.location == 0 {
                let body = trimmedNS.substring(from: match.range.length)
                return MarkdownPreviewBlock(
                    index: index,
                    kind: .bullet(body, level: min(leadingWhitespace / 2, 3))
                )
            }
            return MarkdownPreviewBlock(index: index, kind: .paragraph(line))
        }
    }
}

private enum MarkdownInlineRenderer {
    static func attributedString(for source: String) -> AttributedString {
        segments(for: source).reduce(into: AttributedString()) { output, segment in
            output.append(attributedSegment(segment))
        }
    }

    private static func attributedSegment(_ segment: MarkdownInlineSegment) -> AttributedString {
        var attributed = AttributedString(segment.text)
        var intent = InlinePresentationIntent()

        if segment.style.contains(.bold) {
            intent.insert(.stronglyEmphasized)
        }
        if segment.style.contains(.italic) {
            intent.insert(.emphasized)
        }
        if segment.style.contains(.code) {
            intent.insert(.code)
            attributed.backgroundColor = Color.secondary.opacity(0.14)
        }
        if intent != [] {
            attributed.inlinePresentationIntent = intent
        }
        if segment.style.contains(.highlight) {
            attributed.backgroundColor = Color.yellow.opacity(0.32)
        }
        if let link = segment.link {
            attributed.link = link
            attributed.foregroundColor = .accentColor
            attributed.underlineStyle = .single
        }
        return attributed
    }

    private static func segments(for source: String) -> [MarkdownInlineSegment] {
        var segments: [MarkdownInlineSegment] = []
        var buffer = ""
        var style: MarkdownInlineStyle = []
        var index = source.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            segments.append(MarkdownInlineSegment(text: buffer, style: style))
            buffer = ""
        }

        while index < source.endIndex {
            if style.contains(.code) {
                if source[index] == "`" {
                    flush()
                    style.remove(.code)
                } else {
                    buffer.append(source[index])
                }
                source.formIndex(after: &index)
                continue
            }

            if source[index] == "`", canToggle(marker: "`", from: index, in: source, isClosing: style.contains(.code)) {
                flush()
                style.toggle(.code)
                source.formIndex(after: &index)
                continue
            }

            if let link = parseLink(from: index, in: source) {
                flush()
                segments.append(MarkdownInlineSegment(text: link.label, style: style, link: link.url))
                index = link.endIndex
                continue
            }

            if hasPrefix("***", in: source, at: index),
               canToggle(marker: "***", from: index, in: source, isClosing: style.contains([.bold, .italic])) {
                flush()
                style.toggle(.bold)
                style.toggle(.italic)
                source.formIndex(&index, offsetBy: 3)
                continue
            }

            if hasPrefix("**", in: source, at: index),
               canToggle(marker: "**", from: index, in: source, isClosing: style.contains(.bold)) {
                flush()
                style.toggle(.bold)
                source.formIndex(&index, offsetBy: 2)
                continue
            }

            if hasPrefix("==", in: source, at: index),
               canToggle(marker: "==", from: index, in: source, isClosing: style.contains(.highlight)) {
                flush()
                style.toggle(.highlight)
                source.formIndex(&index, offsetBy: 2)
                continue
            }

            if source[index] == "*",
               canToggle(marker: "*", from: index, in: source, isClosing: style.contains(.italic)) {
                flush()
                style.toggle(.italic)
                source.formIndex(after: &index)
                continue
            }

            buffer.append(source[index])
            source.formIndex(after: &index)
        }

        flush()
        return segments
    }

    private static func canToggle(marker: String, from index: String.Index, in source: String, isClosing: Bool) -> Bool {
        if isClosing { return true }
        let searchStart = source.index(index, offsetBy: marker.count)
        if marker == "*" {
            return hasClosingSingleAsterisk(after: searchStart, in: source)
        }
        return source.range(of: marker, range: searchStart..<source.endIndex) != nil
    }

    private static func hasClosingSingleAsterisk(after index: String.Index, in source: String) -> Bool {
        var scan = index
        while scan < source.endIndex {
            if source[scan] == "*" {
                let previousIsAsterisk = scan > source.startIndex && source[source.index(before: scan)] == "*"
                let next = source.index(after: scan)
                let nextIsAsterisk = next < source.endIndex && source[next] == "*"
                if !previousIsAsterisk && !nextIsAsterisk {
                    return true
                }
            }
            source.formIndex(after: &scan)
        }
        return false
    }

    private static func hasPrefix(_ marker: String, in source: String, at index: String.Index) -> Bool {
        source[index...].hasPrefix(marker)
    }

    private static func parseLink(from index: String.Index, in source: String) -> (label: String, url: URL, endIndex: String.Index)? {
        guard source[index] == "[" else { return nil }

        var labelEnd = source.index(after: index)
        while labelEnd < source.endIndex {
            if source[labelEnd] == "]", !isEscaped(labelEnd, in: source) {
                break
            }
            source.formIndex(after: &labelEnd)
        }
        guard labelEnd < source.endIndex else { return nil }

        let openParen = source.index(after: labelEnd)
        guard openParen < source.endIndex, source[openParen] == "(" else { return nil }

        var urlEnd = source.index(after: openParen)
        while urlEnd < source.endIndex {
            if source[urlEnd] == ")" {
                break
            }
            source.formIndex(after: &urlEnd)
        }
        guard urlEnd < source.endIndex else { return nil }

        let label = String(source[source.index(after: index)..<labelEnd])
            .replacingOccurrences(of: "\\[", with: "[")
            .replacingOccurrences(of: "\\]", with: "]")
        let urlText = String(source[source.index(after: openParen)..<urlEnd])
        guard let url = URL(string: urlText) else { return nil }

        return (label, url, source.index(after: urlEnd))
    }

    private static func isEscaped(_ index: String.Index, in source: String) -> Bool {
        var slashCount = 0
        var scan = index
        while scan > source.startIndex {
            source.formIndex(before: &scan)
            guard source[scan] == "\\" else { break }
            slashCount += 1
        }
        return slashCount % 2 == 1
    }
}

private struct MarkdownInlineSegment {
    let text: String
    let style: MarkdownInlineStyle
    var link: URL?
}

private struct MarkdownInlineStyle: OptionSet {
    let rawValue: Int

    static let bold = MarkdownInlineStyle(rawValue: 1 << 0)
    static let italic = MarkdownInlineStyle(rawValue: 1 << 1)
    static let highlight = MarkdownInlineStyle(rawValue: 1 << 2)
    static let code = MarkdownInlineStyle(rawValue: 1 << 3)

    mutating func toggle(_ option: MarkdownInlineStyle) {
        if contains(option) {
            remove(option)
        } else {
            insert(option)
        }
    }
}

struct MarkdownPreviewBlock: Identifiable {
    let index: Int
    let kind: Kind

    var id: Int { index }

    enum Kind {
        case paragraph(String)
        case bullet(String, level: Int)
        case empty
    }
}
