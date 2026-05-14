import SwiftUI

struct ClipCard: View {
    let clip: Clip
    var fillColor: Color?
    let isSelected: Bool
    var showsContent = true
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    var isEditing = false
    var editingText = ""
    let onCommitEditing: (String) -> Void
    var onExitEditing: () -> Void = {}
    var onEditorSizeChange: (CGSize) -> Void = { _ in }
    let onResize: (CGSize) -> Void
    let onResizeEnded: () -> Void
    let onToggleExpandedSize: () -> Void

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

            resizeHandle
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
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(perform: onTap)
        .gesture(
            isEditing ? DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 40 && abs(value.translation.width) < 80 {
                        onExitEditing()
                    }
                } : nil
        )
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isSelected)
    }

    private var content: some View {
        Group {
            if !showsContent {
                Color.clear
            } else if isEditing, clip.type != .image {
                NoteTextEditor(
                    initialText: editingText,
                    onCommit: onCommitEditing,
                    onExitEditing: onExitEditing,
                    onSizeChange: onEditorSizeChange
                )
            } else if clip.type == .image, let data = clip.imageData, let image = PlatformImage(data: data) {
                platformImage(image)
            } else {
                Text(clip.preview.isEmpty ? " " : clip.preview)
                    .font(.system(size: 15))
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
            (fillColor ?? primaryColor).opacity(0.20)
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
                Text(tag.name)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .foregroundStyle(.primary.opacity(0.78))
                    .background((Color(hex: tag.colorHex) ?? .accentColor).opacity(0.18), in: Capsule())
            }
        }
    }
}

struct StickyNoteShape: InsettableShape {
    var cutSize: CGFloat = 22
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(cutSize, rect.width * 0.24, rect.height * 0.24)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> StickyNoteShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

struct NoteTextEditor: View {
    let initialText: String
    var fontSize: CGFloat = 15
    let onCommit: (String) -> Void
    var onExitEditing: () -> Void = {}
    var onSizeChange: (CGSize) -> Void = { _ in }
    @State private var text: String

    init(
        initialText: String,
        fontSize: CGFloat = 15,
        onCommit: @escaping (String) -> Void,
        onExitEditing: @escaping () -> Void = {},
        onSizeChange: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.initialText = initialText
        self.fontSize = fontSize
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
            .onAppear {
                reportSize(for: text)
            }
            .onDisappear {
                onCommit(text)
            }
    }

    private func reportSize(for value: String) {
        let columns = max(Int((220 / max(fontSize * 0.58, 1)).rounded(.down)), 1)
        let lines = value.components(separatedBy: .newlines).reduce(0) { count, line in
            count + max(Int((Double(max(line.count, 1)) / Double(columns)).rounded(.up)), 1)
        }
        onSizeChange(CGSize(width: 220, height: CGFloat(lines) * fontSize * 1.28))
    }
}

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
