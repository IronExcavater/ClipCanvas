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

        // Re-parses **...** markers and applies bold NSAttributedString attributes
        // so users see visual bold while the plain text (with markers) is preserved.
        func refreshAttributes(_ textView: UITextView) {
            let plain = textView.text ?? ""
            let nsRange = NSRange(plain.startIndex..., in: plain)
            let attr = NSMutableAttributedString(string: plain, attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor.label
            ])
            Self.boldPattern?.enumerateMatches(in: plain, range: nsRange) { match, _, _ in
                guard let match else { return }
                attr.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: match.range)
            }
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
            let range = textView.selectedRange
            let source = textView.text ?? ""
            let ns = source as NSString
            let selected = range.length > 0 ? ns.substring(with: range) : placeholder
            let replacement = "\(prefix)\(selected)\(suffix)"
            textView.text = ns.replacingCharacters(in: range, with: replacement)
            let cursorOffset = range.length > 0 ? replacement.count : prefix.count + selected.count
            textView.selectedRange = NSRange(location: range.location + cursorOffset, length: 0)
        }

        private func applyBullet(in textView: UITextView) {
            let source = textView.text ?? ""
            let ns = source as NSString
            let range = ns.lineRange(for: textView.selectedRange)
            let selectedLines = ns.substring(with: range)
            let replacement = selectedLines
                .components(separatedBy: .newlines)
                .map { line in
                    guard !line.isEmpty else { return line }
                    return line.hasPrefix("- ") ? String(line.dropFirst(2)) : "- \(line)"
                }
                .joined(separator: "\n")
            textView.text = ns.replacingCharacters(in: range, with: replacement)
            textView.selectedRange = NSRange(location: range.location + replacement.count, length: 0)
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
