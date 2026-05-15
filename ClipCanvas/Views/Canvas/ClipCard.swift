import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ClipCard: View {
    let clip: Clip
    var fillColor: Color?
    let isSelected: Bool
    var showsContent = true
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    var isEditing = false
    var editingText = ""
    var fontSize: CGFloat = 15
    var textCommand: NoteTextCommand?
    let onCommitEditing: (String) -> Void
    var onExitEditing: () -> Void = {}
    var onEditorSizeChange: (CGSize) -> Void = { _ in }
    let onResize: (CGSize) -> Void
    let onResizeEnded: () -> Void
    let onToggleExpandedSize: () -> Void

    @ObservedObject private var revealStore = PrivateClipRevealStore.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, clip.tags.isEmpty ? 14 : 36)

            if !clip.tags.isEmpty {
                CanvasNoteTagFooter(tags: Array(clip.tags.sorted { $0.sortIndex < $1.sortIndex }.prefix(3)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
                    .padding(.trailing, 42)
            }

            if !isEditing {
                resizeHandle
            }

            if clip.isPrivateContent {
                privateRevealButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
            }
        }
        .background {
            cardSurface
                .clipShape(StickyNoteShape())
        }
        .overlay(
            StickyNoteShape()
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.09), radius: isSelected ? 10 : 6, y: isSelected ? 4 : 2)
        .contentShape(StickyNoteShape())
        .gesture(tapGesture)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isSelected)
    }

    private var tapGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    onDoubleTap()
                case .second:
                    onTap()
                }
            }
    }

    private var content: some View {
        Group {
            if !showsContent {
                Color.clear
            } else if clip.isPrivateContent && !isRevealed {
                privatePlaceholder
            } else if isEditing, clip.type != .image {
                NoteTextEditor(
                    initialText: editingText,
                    fontSize: fontSize,
                    command: textCommand,
                    onCommit: onCommitEditing,
                    onExitEditing: onExitEditing,
                    onSizeChange: onEditorSizeChange
                )
            } else if clip.type == .image, let data = clip.imageData, let image = PlatformImage(data: data) {
                platformImage(image)
            } else {
                Text(displayPreview.isEmpty ? " " : displayPreview)
                    .font(.system(size: fontSize))
                    .lineLimit(nil)
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private func platformImage(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .clipped()
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .clipped()
        #endif
    }

    private var isRevealed: Bool {
        revealStore.isRevealed(clip)
    }

    private var displayPreview: String {
        clip.displayPreview(isRevealed: isRevealed)
    }

    private var privatePlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
            Text(clip.maskedPreview)
                .font(.system(size: fontSize, weight: .medium))
                .lineLimit(3)
        }
        .foregroundStyle(.primary.opacity(0.72))
    }

    private var privateRevealButton: some View {
        Button {
            revealStore.toggle(clip)
        } label: {
            Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.88), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Hide sensitive content" : "Reveal sensitive content")
    }

    private var resizeHandle: some View {
        CanvasResizeHandle(
            onResize: onResize,
            onResizeEnded: onResizeEnded,
            onToggleExpandedSize: onToggleExpandedSize
        )
    }

    private var cardSurface: some View {
        ZStack {
            Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground)
            (fillColor ?? primaryColor).opacity(0.18)
            StickyNoteFoldOverlay()
        }
    }

    private var primaryColor: Color {
        return clip.color.background
    }
}

struct CanvasNoteTagFooter: View {
    let tags: [ClipTag]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags) { tag in
                AppTagPill(
                    title: tag.name,
                    color: tag.color,
                    icon: "tag",
                    isSelected: false,
                    size: .compact
                )
            }
        }
    }
}

struct StickyNoteShape: InsettableShape {
    var foldSize: CGFloat = 18
    var cornerRadius: CGFloat = 10
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let fold = min(foldSize, rect.width * 0.20, rect.height * 0.20)
        let r = min(cornerRadius, rect.width * 0.12, rect.height * 0.12)
        var path = Path()
        // Start bottom-left, go clockwise
        path.move(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - r),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        // Fold corner — straight lines to preserve the classic sticky note look
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + r),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> StickyNoteShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

struct StickyNoteFoldOverlay: View {
    var foldSize: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let fold = min(foldSize, geo.size.width * 0.20, geo.size.height * 0.20)
            Path { path in
                let x = geo.size.width - fold
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: fold))
                path.addLine(to: CGPoint(x: x, y: fold))
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.06))
            Path { path in
                let x = geo.size.width - fold
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: fold))
            }
            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }
}

#if canImport(UIKit)
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
        tv.font = .systemFont(ofSize: fontSize)
        tv.textColor = .label
        tv.isScrollEnabled = false
        tv.isEditable = true
        tv.text = initialText
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        DispatchQueue.main.async { tv.becomeFirstResponder() }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.font = .systemFont(ofSize: fontSize)
        if let command {
            context.coordinator.apply(command, to: uiView)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: String
        let onCommit: (String) -> Void
        let onExitEditing: () -> Void
        let onSizeChange: (CGSize) -> Void
        weak var textView: UITextView?
        private var hasExited = false
        private var lastCommandID: UUID?

        init(
            text: String,
            onCommit: @escaping (String) -> Void,
            onExitEditing: @escaping () -> Void,
            onSizeChange: @escaping (CGSize) -> Void
        ) {
            self.text = text
            self.onCommit = onCommit
            self.onExitEditing = onExitEditing
            self.onSizeChange = onSizeChange
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text ?? ""
            onCommit(text)
            reportSize(textView)
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
            reportSize(textView)
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

struct ResizeHandle: View {
    var body: some View {
        Canvas { ctx, size in
            let count = 3
            let spacing: CGFloat = 6
            let lineWidth: CGFloat = 1.5
            for i in 0..<count {
                let offset = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: size.width - offset - spacing, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height - offset - spacing))
                ctx.stroke(path, with: .color(.secondary.opacity(0.55)), lineWidth: lineWidth)
            }
        }
        .frame(width: 28, height: 28)
        .padding(6)
        .contentShape(Rectangle())
    }
}

extension CardColor {
    var background: Color {
        switch self {
        case .cloud:    return .adaptive(light: PlatformColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1), dark: PlatformColor(red: 0.22, green: 0.22, blue: 0.21, alpha: 1))
        case .banana:   return .adaptive(light: PlatformColor(red: 1.00, green: 0.95, blue: 0.46, alpha: 1), dark: PlatformColor(red: 0.42, green: 0.38, blue: 0.03, alpha: 1))
        case .flamingo: return .adaptive(light: PlatformColor(red: 1.00, green: 0.67, blue: 0.67, alpha: 1), dark: PlatformColor(red: 0.50, green: 0.17, blue: 0.17, alpha: 1))
        case .sage:     return .adaptive(light: PlatformColor(red: 0.71, green: 0.92, blue: 0.84, alpha: 1), dark: PlatformColor(red: 0.10, green: 0.36, blue: 0.26, alpha: 1))
        case .sky:      return .adaptive(light: PlatformColor(red: 0.68, green: 0.84, blue: 0.95, alpha: 1), dark: PlatformColor(red: 0.10, green: 0.29, blue: 0.44, alpha: 1))
        case .lavender: return .adaptive(light: PlatformColor(red: 0.84, green: 0.74, blue: 0.89, alpha: 1), dark: PlatformColor(red: 0.30, green: 0.18, blue: 0.40, alpha: 1))
        case .peach:    return .adaptive(light: PlatformColor(red: 1.00, green: 0.85, blue: 0.76, alpha: 1), dark: PlatformColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 1))
        }
    }
}
