import SwiftUI
#if canImport(UIKit)
import UIKit

struct NoteTextEditor: UIViewRepresentable {
    let initialText: String
    var fontSize: CGFloat = 15
    var command: NoteTextCommand?
    let onCommit: (String) -> Void
    var onExitEditing: () -> Void = {}
    var onSizeChange: (CGSize) -> Void = { _ in }

    init(
        initialText: String,
        fontSize: CGFloat = 15,
        command: NoteTextCommand? = nil,
        onCommit: @escaping (String) -> Void,
        onExitEditing: @escaping () -> Void = {},
        onSizeChange: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.initialText = initialText
        self.fontSize = fontSize
        self.command = command
        self.onCommit = onCommit
        self.onExitEditing = onExitEditing
        self.onSizeChange = onSizeChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: initialText,
            fontSize: fontSize,
            onCommit: onCommit,
            onExitEditing: onExitEditing,
            onSizeChange: onSizeChange
        )
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        tv.backgroundColor = .clear
        tv.textColor = .label
        tv.isScrollEnabled = true
        tv.isEditable = true
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.text = initialText
        DispatchQueue.main.async {
            tv.becomeFirstResponder()
            context.coordinator.refreshAttributes(tv)
            context.coordinator.reportSize(tv)
            context.coordinator.scrollCaretIntoView(tv)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if let command {
            context.coordinator.apply(command, to: uiView)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: String
        var fontSize: CGFloat
        let onCommit: (String) -> Void
        let onExitEditing: () -> Void
        let onSizeChange: (CGSize) -> Void
        weak var textView: UITextView?
        private var hasExited = false
        private var lastCommandID: UUID?
        private static let boldPattern = try? NSRegularExpression(
            pattern: #"\*\*(.+?)\*\*"#,
            options: .dotMatchesLineSeparators
        )
        private static let italicPattern = try? NSRegularExpression(
            pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#,
            options: .dotMatchesLineSeparators
        )
        private static let highlightPattern = try? NSRegularExpression(
            pattern: #"==(.+?)=="#,
            options: .dotMatchesLineSeparators
        )
        private static let inlineCodePattern = try? NSRegularExpression(
            pattern: #"`(.+?)`"#,
            options: .dotMatchesLineSeparators
        )
        private static let bulletPattern = try? NSRegularExpression(
            pattern: #"(?m)^(\s*)[-*]\s+"#,
            options: []
        )

        init(
            text: String,
            fontSize: CGFloat,
            onCommit: @escaping (String) -> Void,
            onExitEditing: @escaping () -> Void,
            onSizeChange: @escaping (CGSize) -> Void
        ) {
            self.text = text
            self.fontSize = fontSize
            self.onCommit = onCommit
            self.onExitEditing = onExitEditing
            self.onSizeChange = onSizeChange
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text ?? ""
            onCommit(text)
            refreshAttributes(textView)
            reportSize(textView)
            scrollCaretIntoView(textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            textView.contentOffset = .zero
            onCommit(text)
            guard !hasExited else { return }
            hasExited = true
            onExitEditing()
        }

        func apply(_ command: NoteTextCommand, to textView: UITextView) {
            guard lastCommandID != command.id else { return }
            lastCommandID = command.id

            switch command.kind {
            case .bold:
                wrapSelection(in: textView, prefix: "**", suffix: "**", placeholder: "bold")
            case .italic:
                wrapSelection(in: textView, prefix: "*", suffix: "*", placeholder: "italic")
            case .highlight:
                wrapSelection(in: textView, prefix: "==", suffix: "==", placeholder: "highlight")
            case .bullet:
                applyBullet(in: textView)
            }

            text = textView.text ?? ""
            onCommit(text)
            refreshAttributes(textView)
            reportSize(textView)
            scrollCaretIntoView(textView)
        }

        // Re-parses markdown markers so the stored plain text remains editable,
        // while the card shows the formatted result during editing.
        func refreshAttributes(_ textView: UITextView) {
            let plain = textView.text ?? ""
            let nsRange = NSRange(plain.startIndex..., in: plain)
            let attr = NSMutableAttributedString(string: plain, attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor.label
            ])
            applyInlineFontMarkdown(
                pattern: Self.boldPattern,
                to: attr,
                in: plain,
                range: nsRange,
                traits: .traitBold,
                markerLength: 2
            )
            applyInlineFontMarkdown(
                pattern: Self.italicPattern,
                to: attr,
                in: plain,
                range: nsRange,
                traits: .traitItalic,
                markerLength: 1
            )
            applyInlineMarkdown(
                pattern: Self.highlightPattern,
                to: attr,
                in: plain,
                range: nsRange,
                bodyAttributes: [.backgroundColor: UIColor.systemYellow.withAlphaComponent(0.35)],
                markerLength: 2
            )
            applyInlineMarkdown(
                pattern: Self.inlineCodePattern,
                to: attr,
                in: plain,
                range: nsRange,
                bodyAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: max(fontSize - 1, 11), weight: .regular),
                    .backgroundColor: UIColor.secondarySystemFill
                ],
                markerLength: 1
            )
            applyBulletAttributes(to: attr, in: plain, range: nsRange)
            let saved = textView.selectedRange
            textView.attributedText = attr
            let length = (textView.text as NSString?)?.length ?? 0
            if saved.location + saved.length <= length {
                textView.selectedRange = saved
            }
        }

        private func wrapSelection(
            in textView: UITextView,
            prefix: String,
            suffix: String,
            placeholder: String
        ) {
            let source = textView.text ?? ""
            let ns = source as NSString
            let range = markdownBodyRange(for: textView.selectedRange, in: ns)
            let selected = range.length > 0 ? ns.substring(with: range) : placeholder
            let replacement = "\(prefix)\(selected)\(suffix)"
            textView.text = ns.replacingCharacters(in: range, with: replacement)
            let cursorOffset = range.length > 0 ? replacement.count : prefix.count + selected.count
            textView.selectedRange = NSRange(location: range.location + cursorOffset, length: 0)
        }

        private func markdownBodyRange(for selectedRange: NSRange, in ns: NSString) -> NSRange {
            let lineRange = ns.lineRange(for: selectedRange)
            guard lineRange.length >= 2 else { return selectedRange }
            let line = ns.substring(with: lineRange)
            let markerLength: Int
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                markerLength = 2
            } else {
                return selectedRange
            }

            let bodyStart = lineRange.location + markerLength
            if selectedRange.length == 0 {
                return NSRange(location: max(selectedRange.location, bodyStart), length: 0)
            }

            let end = selectedRange.location + selectedRange.length
            let adjustedStart = max(selectedRange.location, bodyStart)
            return NSRange(location: adjustedStart, length: max(0, end - adjustedStart))
        }

        private func applyBullet(in textView: UITextView) {
            let source = textView.text ?? ""
            let ns = source as NSString
            let range = ns.lineRange(for: textView.selectedRange)
            var lines = ns.substring(with: range).components(separatedBy: .newlines)
            let keepsTrailingNewline = lines.last == ""
            if keepsTrailingNewline { lines.removeLast() }
            let replacement = lines.map { line in
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
                if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
                if line.hasPrefix("* ") { return String(line.dropFirst(2)) }
                return "- \(line)"
            }
            .joined(separator: "\n") + (keepsTrailingNewline ? "\n" : "")
            textView.text = ns.replacingCharacters(in: range, with: replacement)
            textView.selectedRange = NSRange(location: range.location + replacement.count, length: 0)
        }

        private func applyInlineMarkdown(
            pattern: NSRegularExpression?,
            to attr: NSMutableAttributedString,
            in plain: String,
            range: NSRange,
            bodyAttributes: [NSAttributedString.Key: Any],
            markerLength: Int
        ) {
            pattern?.enumerateMatches(in: plain, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1 else { return }
                let bodyRange = match.range(at: 1)
                attr.addAttributes(bodyAttributes, range: bodyRange)
                hideMarkdownMarkers(in: attr, matchRange: match.range, bodyRange: bodyRange, markerLength: markerLength)
            }
        }

        private func applyInlineFontMarkdown(
            pattern: NSRegularExpression?,
            to attr: NSMutableAttributedString,
            in plain: String,
            range: NSRange,
            traits: UIFontDescriptor.SymbolicTraits,
            markerLength: Int
        ) {
            pattern?.enumerateMatches(in: plain, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1 else { return }
                let bodyRange = match.range(at: 1)
                attr.enumerateAttribute(.font, in: bodyRange) { value, subrange, _ in
                    let existing = value as? UIFont ?? UIFont.systemFont(ofSize: fontSize)
                    attr.addAttribute(.font, value: font(existing, adding: traits), range: subrange)
                }
                hideMarkdownMarkers(in: attr, matchRange: match.range, bodyRange: bodyRange, markerLength: markerLength)
            }
        }

        private func hideMarkdownMarkers(
            in attr: NSMutableAttributedString,
            matchRange: NSRange,
            bodyRange: NSRange,
            markerLength: Int
        ) {
            let leading = NSRange(location: matchRange.location, length: markerLength)
            let trailing = NSRange(location: bodyRange.location + bodyRange.length, length: markerLength)
            [leading, trailing].forEach { markerRange in
                attr.addAttributes(hiddenMarkerAttributes, range: markerRange)
            }
        }

        private func applyBulletAttributes(to attr: NSMutableAttributedString, in plain: String, range: NSRange) {
            Self.bulletPattern?.enumerateMatches(in: plain, range: range) { match, _, _ in
                guard let match else { return }
                attr.addAttributes(hiddenMarkerAttributes, range: match.range)

                let paragraph = NSMutableParagraphStyle()
                paragraph.headIndent = 18
                paragraph.firstLineHeadIndent = 0
                paragraph.paragraphSpacing = 2
                if #available(iOS 15.0, *) {
                    paragraph.textLists = [NSTextList(markerFormat: .disc, options: 0)]
                }
                let lineRange = (plain as NSString).lineRange(for: match.range)
                attr.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)
            }
        }

        private var hiddenMarkerAttributes: [NSAttributedString.Key: Any] {
            [
                .foregroundColor: UIColor.clear,
                .font: UIFont.systemFont(ofSize: 0.001),
                .kern: -0.001
            ]
        }

        private func font(_ base: UIFont, adding traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
            var combined = base.fontDescriptor.symbolicTraits
            combined.insert(traits)
            guard let descriptor = base.fontDescriptor.withSymbolicTraits(combined) else {
                if traits.contains(.traitBold), traits.contains(.traitItalic) {
                    return UIFont(descriptor: UIFont.boldSystemFont(ofSize: fontSize).fontDescriptor.withSymbolicTraits(.traitItalic) ?? UIFont.italicSystemFont(ofSize: fontSize).fontDescriptor, size: fontSize)
                }
                if traits.contains(.traitBold) { return UIFont.boldSystemFont(ofSize: fontSize) }
                if traits.contains(.traitItalic) { return UIFont.italicSystemFont(ofSize: fontSize) }
                return base
            }
            return UIFont(descriptor: descriptor, size: fontSize)
        }

        func reportSize(_ textView: UITextView) {
            let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
            onSizeChange(size)
        }

        func scrollCaretIntoView(_ textView: UITextView) {
            let length = (textView.text as NSString?)?.length ?? 0
            guard textView.selectedRange.location <= length else { return }
            textView.scrollRangeToVisible(textView.selectedRange)
        }
    }
}
#else
struct NoteTextEditor: View {
    let initialText: String
    var fontSize: CGFloat = 15
    var command: NoteTextCommand?
    let onCommit: (String) -> Void
    var onExitEditing: () -> Void = {}
    var onSizeChange: (CGSize) -> Void = { _ in }

    @State private var text: String
    @State private var lastCommandID: UUID?

    init(
        initialText: String,
        fontSize: CGFloat = 15,
        command: NoteTextCommand? = nil,
        onCommit: @escaping (String) -> Void,
        onExitEditing: @escaping () -> Void = {},
        onSizeChange: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.initialText = initialText
        self.fontSize = fontSize
        self.command = command
        self.onCommit = onCommit
        self.onExitEditing = onExitEditing
        self.onSizeChange = onSizeChange
        _text = State(initialValue: initialText)
    }

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: fontSize))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onChange(of: text) { _, newValue in
                onCommit(newValue)
                reportSize(for: newValue)
            }
            .onChange(of: command?.id) { _, _ in
                applyCommandIfNeeded()
            }
            .onAppear {
                reportSize(for: text)
                applyCommandIfNeeded()
            }
            .onDisappear {
                onCommit(text)
            }
    }

    private func applyCommandIfNeeded() {
        guard let command, lastCommandID != command.id else { return }
        lastCommandID = command.id

        switch command.kind {
        case .bold:
            text = text.isEmpty ? "**bold**" : "**\(text)**"
        case .italic:
            text = text.isEmpty ? "*italic*" : "*\(text)*"
        case .highlight:
            text = text.isEmpty ? "==highlight==" : "==\(text)=="
        case .bullet:
            text = text
                .components(separatedBy: .newlines)
                .map { line in
                    guard !line.isEmpty else { return line }
                    return line.hasPrefix("- ") ? String(line.dropFirst(2)) : "- \(line)"
                }
                .joined(separator: "\n")
        }

        onCommit(text)
        reportSize(for: text)
    }

    private func reportSize(for value: String) {
        let columns = max(Int((220 / max(fontSize * 0.58, 1)).rounded(.down)), 1)
        let lines = value.components(separatedBy: .newlines).reduce(0) { count, line in
            count + max(Int((Double(max(line.count, 1)) / Double(columns)).rounded(.up)), 1)
        }
        onSizeChange(CGSize(width: 220, height: CGFloat(lines) * fontSize * 1.28))
    }
}
#endif
