import Foundation

nonisolated enum NoteTextBlockStyle: String, CaseIterable, Equatable {
    case title
    case heading
    case subheading
    case body
    case monostyled
}

nonisolated enum NoteTextListStyle: String, CaseIterable, Equatable {
    case bullet
    case dashed
    case numbered
    case checklist
}

nonisolated enum NoteHighlightColor: String, CaseIterable, Equatable {
    case yellow
    case green
    case blue
    case pink
    case purple
    case orange
}

nonisolated enum NoteTextCommandKind: Equatable {
    case blockStyle(NoteTextBlockStyle)
    case bold
    case italic
    case underline
    case strikethrough
    case highlight(NoteHighlightColor = .yellow)
    case list(NoteTextListStyle)
    case quote
    case link(url: String, displayText: String?)
    case indent
    case outdent
}

nonisolated struct NoteTextCommand: Equatable {
    let id = UUID()
    let kind: NoteTextCommandKind
}

nonisolated enum NoteTextFormattingEngine {
    struct Result: Equatable {
        var text: String
        var selectedRange: NSRange
    }

    static func apply(_ command: NoteTextCommandKind, to source: String, selectedRange: NSRange) -> Result {
        switch command {
        case .blockStyle(let style):
            return applyLinePrefix(blockPrefix(for: style), to: source, selectedRange: selectedRange, removingExistingBlockPrefix: true)
        case .bold:
            return wrapSelection(in: source, selectedRange: selectedRange, prefix: "**", suffix: "**", placeholder: "bold")
        case .italic:
            return wrapSelection(in: source, selectedRange: selectedRange, prefix: "*", suffix: "*", placeholder: "italic")
        case .underline:
            return wrapSelection(in: source, selectedRange: selectedRange, prefix: "<u>", suffix: "</u>", placeholder: "underline")
        case .strikethrough:
            return wrapSelection(in: source, selectedRange: selectedRange, prefix: "~~", suffix: "~~", placeholder: "strike")
        case .highlight(let color):
            let marker = color == .yellow ? "==" : "==\(color.rawValue):"
            return wrapSelection(in: source, selectedRange: selectedRange, prefix: marker, suffix: "==", placeholder: "highlight")
        case .list(let style):
            return applyList(style, to: source, selectedRange: selectedRange)
        case .quote:
            return toggleQuote(to: source, selectedRange: selectedRange)
        case .link(let url, let displayText):
            let text = nonEmpty(displayText) ?? nonEmpty(selectedText(in: source, selectedRange: selectedRange)) ?? url
            return replaceSelection(in: source, selectedRange: selectedRange, replacement: "[\(text)](\(url))")
        case .indent:
            return adjustIndent(in: source, selectedRange: selectedRange, direction: 1)
        case .outdent:
            return adjustIndent(in: source, selectedRange: selectedRange, direction: -1)
        }
    }

    static func applyNewline(in source: String, selectedRange: NSRange) -> Result? {
        let ns = source as NSString
        let lineRange = ns.lineRange(for: selectedRange)
        let line = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard let marker = listMarker(in: line) else { return nil }
        let body = String(line.dropFirst(marker.fullLength)).trimmingCharacters(in: .whitespaces)

        if body.isEmpty {
            let replacement = String(line.dropFirst(marker.fullLength))
            let fullLineReplacement = ns.replacingCharacters(in: lineRange, with: replacement)
            return Result(text: fullLineReplacement, selectedRange: NSRange(location: lineRange.location + replacement.count, length: 0))
        }

        let nextMarker = marker.nextMarker
        let replacement = "\n\(marker.leading)\(nextMarker)"
        return replaceSelection(in: source, selectedRange: selectedRange, replacement: replacement)
    }

    private static func wrapSelection(in source: String, selectedRange: NSRange, prefix: String, suffix: String, placeholder: String) -> Result {
        let ns = source as NSString
        let selected = selectedRange.length > 0 ? ns.substring(with: selectedRange) : placeholder
        let replacement = "\(prefix)\(selected)\(suffix)"
        let cursorOffset = selectedRange.length > 0 ? replacement.count : prefix.count + selected.count
        let text = ns.replacingCharacters(in: selectedRange, with: replacement)
        return Result(text: text, selectedRange: NSRange(location: selectedRange.location + cursorOffset, length: 0))
    }

    private static func replaceSelection(in source: String, selectedRange: NSRange, replacement: String) -> Result {
        let text = (source as NSString).replacingCharacters(in: selectedRange, with: replacement)
        return Result(text: text, selectedRange: NSRange(location: selectedRange.location + replacement.count, length: 0))
    }

    private static func selectedText(in source: String, selectedRange: NSRange) -> String {
        guard selectedRange.length > 0 else { return "" }
        return (source as NSString).substring(with: selectedRange)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func applyLinePrefix(_ prefix: String, to source: String, selectedRange: NSRange, removingExistingBlockPrefix: Bool = false) -> Result {
        transformLines(in: source, selectedRange: selectedRange) { line, _ in
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            var body = String(line.dropFirst(leading.count))
            if removingExistingBlockPrefix {
                body = removeBlockPrefix(from: body)
            }
            return "\(leading)\(prefix)\(body)"
        }
    }

    private static func toggleQuote(to source: String, selectedRange: NSRange) -> Result {
        let selectedLines = selectedLineStrings(in: source, selectedRange: selectedRange)
        let quotedLines = selectedLines.filter { line in
            let body = line.drop { $0 == " " || $0 == "\t" }
            return body.hasPrefix("> ")
        }
        let shouldRemove = !quotedLines.isEmpty && quotedLines.count == selectedLines.count

        return transformLines(in: source, selectedRange: selectedRange) { line, _ in
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            let body = String(line.dropFirst(leading.count))
            if body.hasPrefix("> ") {
                return shouldRemove ? "\(leading)\(body.dropFirst(2))" : line
            }
            return "\(leading)> \(body)"
        }
    }

    private static func applyList(_ style: NoteTextListStyle, to source: String, selectedRange: NSRange) -> Result {
        transformLines(in: source, selectedRange: selectedRange) { line, index in
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            let body = removeListPrefix(from: String(line.dropFirst(leading.count)))
            return "\(leading)\(marker(for: style, index: index))\(body)"
        }
    }

    private static func adjustIndent(in source: String, selectedRange: NSRange, direction: Int) -> Result {
        transformLines(in: source, selectedRange: selectedRange) { line, _ in
            if direction > 0 {
                return "  \(line)"
            }
            if line.hasPrefix("  ") { return String(line.dropFirst(2)) }
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            return line
        }
    }

    private static func transformLines(in source: String, selectedRange: NSRange, transform: (String, Int) -> String) -> Result {
        let ns = source as NSString
        let range = ns.lineRange(for: selectedRange)
        let selectedLines = ns.substring(with: range)
        var lines = selectedLines.components(separatedBy: .newlines)
        let keepsTrailingNewline = !selectedLines.isEmpty && lines.last == ""
        if keepsTrailingNewline { lines.removeLast() }
        let replacement = lines.enumerated().map { transform($0.element, $0.offset) }.joined(separator: "\n") + (keepsTrailingNewline ? "\n" : "")
        let text = ns.replacingCharacters(in: range, with: replacement)
        return Result(text: text, selectedRange: NSRange(location: range.location + replacement.count, length: 0))
    }

    private static func selectedLineStrings(in source: String, selectedRange: NSRange) -> [String] {
        let ns = source as NSString
        let range = ns.lineRange(for: selectedRange)
        let selectedLines = ns.substring(with: range)
        var lines = selectedLines.components(separatedBy: .newlines)
        if !selectedLines.isEmpty, lines.last == "" {
            lines.removeLast()
        }
        return lines
    }

    private static func marker(for style: NoteTextListStyle, index: Int) -> String {
        switch style {
        case .bullet: return "* "
        case .dashed: return "- "
        case .numbered: return "\(index + 1). "
        case .checklist: return "- [ ] "
        }
    }

    private static func blockPrefix(for style: NoteTextBlockStyle) -> String {
        switch style {
        case .title: return "# "
        case .heading: return "## "
        case .subheading: return "### "
        case .body: return ""
        case .monostyled: return "    "
        }
    }

    private static func removeBlockPrefix(from line: String) -> String {
        if line.hasPrefix("### ") { return String(line.dropFirst(4)) }
        if line.hasPrefix("## ") { return String(line.dropFirst(3)) }
        if line.hasPrefix("# ") { return String(line.dropFirst(2)) }
        if line.hasPrefix("    ") { return String(line.dropFirst(4)) }
        return line
    }

    private static func removeListPrefix(from line: String) -> String {
        if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") { return String(line.dropFirst(6)) }
        if line.hasPrefix("- ") || line.hasPrefix("* ") { return String(line.dropFirst(2)) }
        var numberLength = 0
        for character in line {
            guard character.isNumber else { break }
            numberLength += 1
        }
        if numberLength > 0 {
            let dot = line.index(line.startIndex, offsetBy: numberLength)
            if dot < line.endIndex, line[dot] == "." {
                let afterDot = line.index(after: dot)
                if afterDot < line.endIndex, line[afterDot].isWhitespace {
                    return String(line.dropFirst(numberLength + 2))
                }
            }
        }
        return line
    }

    private static func listMarker(in line: String) -> (leading: String, fullLength: Int, nextMarker: String)? {
        let leading = String(line.prefix { $0 == " " || $0 == "\t" })
        let body = String(line.dropFirst(leading.count))
        if body.hasPrefix("- [ ] ") { return (leading, leading.count + 6, "- [ ] ") }
        if body.hasPrefix("- [x] ") { return (leading, leading.count + 6, "- [ ] ") }
        if body.hasPrefix("- ") { return (leading, leading.count + 2, "- ") }
        if body.hasPrefix("* ") { return (leading, leading.count + 2, "* ") }

        var numberLength = 0
        for character in body {
            guard character.isNumber else { break }
            numberLength += 1
        }
        if numberLength > 0 {
            let number = Int(body.prefix(numberLength)) ?? 0
            let dot = body.index(body.startIndex, offsetBy: numberLength)
            if dot < body.endIndex, body[dot] == "." {
                let afterDot = body.index(after: dot)
                if afterDot < body.endIndex, body[afterDot].isWhitespace {
                    return (leading, leading.count + numberLength + 2, "\(number + 1). ")
                }
            }
        }
        return nil
    }
}
