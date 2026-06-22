import SwiftUI

struct MarkdownPreview: View {
    let text: String
    var emptyText = " "
    var revealedSensitiveParts: Set<String> = []
    var onSensitivePartTapped: (String) -> Void = { _ in }
    private static let orderedListPattern = try? NSRegularExpression(pattern: #"^\d+\.\s+"#)

    var body: some View {
        let blocks = Self.blocks(for: text, emptyText: emptyText)
        if blocks.count == 1, case .paragraph(let content) = blocks[0].kind {
            Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                .environment(\.openURL, sensitiveOpenURLAction)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(blocks) { block in
                    switch block.kind {
                    case .heading(let content, let level):
                        Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                            .font(headingFont(level: level))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .paragraph(let content):
                        Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .monostyled(let content):
                        Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                            .font(.body.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .bullet(let content, let level):
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("•")
                                .fontWeight(.semibold)
                                .frame(width: 10, alignment: .center)
                            Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, CGFloat(level) * 16)
                    case .ordered(let content, let number, let level):
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("\(number).")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .frame(width: 22, alignment: .trailing)
                            Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, CGFloat(level) * 16)
                    case .checklist(let content, let isChecked, let level):
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                .font(.caption.weight(.semibold))
                                .frame(width: 14, alignment: .center)
                                .foregroundStyle(isChecked ? Color.accentColor : Color.secondary)
                            Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, CGFloat(level) * 16)
                    case .quote(let content):
                        Text(Self.attributedString(for: content, emptyText: emptyText, revealedSensitiveParts: revealedSensitiveParts))
                            .padding(.leading, 10)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(Color.secondary.opacity(0.45)).frame(width: 3)
                            }
                    case .empty:
                        Text(" ")
                    }
                }
            }
            .environment(\.openURL, sensitiveOpenURLAction)
        }
    }

    static func attributedString(for text: String, emptyText: String = " ") -> AttributedString {
        attributedString(for: text, emptyText: emptyText, revealedSensitiveParts: [])
    }

    static func attributedString(
        for text: String,
        emptyText: String = " ",
        revealedSensitiveParts: Set<String>
    ) -> AttributedString {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyText : text
        return MarkdownInlineRenderer.attributedString(for: source, revealedSensitiveParts: revealedSensitiveParts)
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
            if line.hasPrefix("    ") {
                return MarkdownPreviewBlock(index: index, kind: .monostyled(String(line.dropFirst(4))))
            }
            if trimmed.hasPrefix("# ") {
                return MarkdownPreviewBlock(index: index, kind: .heading(String(trimmed.dropFirst(2)), level: 1))
            }
            if trimmed.hasPrefix("## ") {
                return MarkdownPreviewBlock(index: index, kind: .heading(String(trimmed.dropFirst(3)), level: 2))
            }
            if trimmed.hasPrefix("### ") {
                return MarkdownPreviewBlock(index: index, kind: .heading(String(trimmed.dropFirst(4)), level: 3))
            }
            if trimmed.hasPrefix("> ") {
                return MarkdownPreviewBlock(index: index, kind: .quote(String(trimmed.dropFirst(2))))
            }
            if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") {
                let body = (trimmed as NSString).substring(from: 6)
                return MarkdownPreviewBlock(
                    index: index,
                    kind: .checklist(body, isChecked: trimmed.hasPrefix("- [x] "), level: min(leadingWhitespace / 2, 3))
                )
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
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
                let marker = trimmedNS.substring(with: match.range)
                let number = Int(marker.prefix { $0.isNumber }) ?? index + 1
                return MarkdownPreviewBlock(
                    index: index,
                    kind: .ordered(body, number: number, level: min(leadingWhitespace / 2, 3))
                )
            }
            return MarkdownPreviewBlock(index: index, kind: .paragraph(line))
        }
    }

    private var sensitiveOpenURLAction: OpenURLAction {
        OpenURLAction { url in
            guard url.scheme == "clipcanvas-sensitive",
                  let id = url.host?.removingPercentEncoding else {
                return .systemAction
            }
            onSensitivePartTapped(id)
            return .handled
        }
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: return .title2.weight(.bold)
        case 2: return .headline.weight(.bold)
        default: return .subheadline.weight(.semibold)
        }
    }
}

private enum MarkdownInlineRenderer {
    static func attributedString(for source: String, revealedSensitiveParts: Set<String>) -> AttributedString {
        segments(for: source).reduce(into: AttributedString()) { output, segment in
            if segment.style.contains(.sensitive), let id = segment.sensitivePartID {
                output.append(attributedSensitiveSegment(segment, id: id, revealed: revealedSensitiveParts.contains(id)))
                return
            }
            output.append(attributedSegment(segment))
        }
    }

    private static func attributedSensitiveSegment(_ segment: MarkdownInlineSegment, id: String, revealed: Bool) -> AttributedString {
        let visibleText = revealed ? segment.text : SensitiveClipDisplay.mask(for: segment.text)
        var attributed = AttributedString(visibleText)
        let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? id
        attributed.link = URL(string: "clipcanvas-sensitive://\(encodedID)")
        attributed.backgroundColor = Color.red.opacity(0.18)
        attributed.foregroundColor = .primary
        attributed.underlineStyle = .single
        return attributed
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
            attributed.backgroundColor = color(for: segment.highlightColor ?? .yellow).opacity(0.32)
        }
        if segment.style.contains(.underline) {
            attributed.underlineStyle = .single
        }
        if segment.style.contains(.strikethrough) {
            attributed.strikethroughStyle = .single
        }
        if let link = segment.link {
            attributed.link = link
            attributed.foregroundColor = .accentColor
            attributed.underlineStyle = .single
        }
        return attributed
    }

    private static func color(for highlight: NoteHighlightColor) -> Color {
        switch highlight {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        case .purple: return .purple
        case .orange: return .orange
        }
    }

    private static func segments(for source: String) -> [MarkdownInlineSegment] {
        var segments: [MarkdownInlineSegment] = []
        var buffer = ""
        var style: MarkdownInlineStyle = []
        var highlightColor: NoteHighlightColor?
        var index = source.startIndex
        var sensitiveOccurrence = 0

        func flush() {
            guard !buffer.isEmpty else { return }
            let id: String?
            if style.contains(.sensitive) {
                id = SensitiveTextPart(text: buffer, occurrence: sensitiveOccurrence).id
                sensitiveOccurrence += 1
            } else {
                id = nil
            }
            segments.append(MarkdownInlineSegment(text: buffer, style: style, highlightColor: highlightColor, sensitivePartID: id))
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
                if style.contains(.highlight) {
                    style.remove(.highlight)
                    highlightColor = nil
                    source.formIndex(&index, offsetBy: 2)
                } else {
                    style.insert(.highlight)
                    let parsedColor = parseHighlightColor(from: source.index(index, offsetBy: 2), in: source)
                    highlightColor = parsedColor.color
                    index = parsedColor.contentStart
                }
                continue
            }

            if hasPrefix("<u>", in: source, at: index),
               source.range(of: "</u>", range: source.index(index, offsetBy: 3)..<source.endIndex) != nil {
                flush()
                style.insert(.underline)
                source.formIndex(&index, offsetBy: 3)
                continue
            }

            if hasPrefix("</u>", in: source, at: index), style.contains(.underline) {
                flush()
                style.remove(.underline)
                source.formIndex(&index, offsetBy: 4)
                continue
            }

            if hasPrefix("~~", in: source, at: index),
               canToggle(marker: "~~", from: index, in: source, isClosing: style.contains(.strikethrough)) {
                flush()
                style.toggle(.strikethrough)
                source.formIndex(&index, offsetBy: 2)
                continue
            }

            if hasPrefix("||", in: source, at: index),
               canToggle(marker: "||", from: index, in: source, isClosing: style.contains(.sensitive)) {
                flush()
                style.toggle(.sensitive)
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

    private static func parseHighlightColor(from index: String.Index, in source: String) -> (color: NoteHighlightColor?, contentStart: String.Index) {
        guard let colon = source[index...].firstIndex(of: ":") else {
            return (.yellow, index)
        }
        let candidate = String(source[index..<colon])
        guard let color = NoteHighlightColor(rawValue: candidate) else {
            return (.yellow, index)
        }
        return (color, source.index(after: colon))
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
    var highlightColor: NoteHighlightColor?
    var sensitivePartID: String?
}

private struct MarkdownInlineStyle: OptionSet {
    let rawValue: Int

    static let bold = MarkdownInlineStyle(rawValue: 1 << 0)
    static let italic = MarkdownInlineStyle(rawValue: 1 << 1)
    static let highlight = MarkdownInlineStyle(rawValue: 1 << 2)
    static let code = MarkdownInlineStyle(rawValue: 1 << 3)
    static let sensitive = MarkdownInlineStyle(rawValue: 1 << 4)
    static let underline = MarkdownInlineStyle(rawValue: 1 << 5)
    static let strikethrough = MarkdownInlineStyle(rawValue: 1 << 6)

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
        case heading(String, level: Int)
        case paragraph(String)
        case monostyled(String)
        case bullet(String, level: Int)
        case ordered(String, number: Int, level: Int)
        case checklist(String, isChecked: Bool, level: Int)
        case quote(String)
        case empty
    }
}
