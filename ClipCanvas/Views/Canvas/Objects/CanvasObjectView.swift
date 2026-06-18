import SwiftUI

struct CanvasObjectView: View {
    let object: CanvasObject
    let isSelected: Bool
    var showsContent = true
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    var isEditing = false
    var editingText = ""
    var textCommand: NoteTextCommand?
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
                .padding(.bottom, noteTags.isEmpty ? 14 : 36)

            if !noteTags.isEmpty {
                CanvasNoteTagFooter(tags: noteTags)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
                    .padding(.trailing, 42)
            }

            if !isEditing {
                CanvasResizeHandle(
                    onResize: onResize,
                    onResizeEnded: onResizeEnded,
                    onToggleExpandedSize: onToggleExpandedSize
                )
            }
        }
        .background {
            if usesStickySurface {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fillColor.opacity(0.20))
                }
            } else if object.kind == .text {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.clear)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fillColor)
            }
        }
        .overlay {
            if usesStickySurface {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            } else if object.kind == .text {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : strokeColor, lineWidth: isSelected ? 2.5 : 1)
            }
        }
        .shadow(
            color: .black.opacity(object.kind == .text ? 0 : (isSelected ? 0.16 : 0.08)),
            radius: object.kind == .text ? 0 : (isSelected ? 10 : 5),
            y: object.kind == .text ? 0 : (isSelected ? 4 : 2)
        )
        .contentShape(Rectangle())
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

    private var noteFontSize: CGFloat {
        CanvasPlacementSizing.fontSizeForContent(object.text, width: object.width)
    }

    @ViewBuilder
    private var content: some View {
        if !showsContent {
            Color.clear
        } else if isEditing, usesEditableText {
            NoteTextEditor(
                initialText: editingText,
                fontSize: noteFontSize,
                command: textCommand,
                onCommit: onCommitEditing,
                onExitEditing: onExitEditing,
                onSizeChange: onEditorSizeChange
            )
        } else {
            switch object.kind {
            case .image:
                Label(object.text.isEmpty ? "Image" : object.text, systemImage: "photo")
                    .font(.headline)
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .shape:
                shapeContent
            case .drawing:
                Label("Drawing", systemImage: "pencil.tip")
                    .font(.headline)
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .group:
                Label(object.text.isEmpty ? "Group" : object.text, systemImage: "rectangle.3.group")
                    .font(.headline)
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            default:
                MarkdownPreview(text: object.displayText.isEmpty ? " " : object.displayText)
                    .font(.system(size: usesStickySurface ? noteFontSize : object.style.fontSize))
                    .foregroundStyle(textColor)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: usesStickySurface ? .infinity : nil,
                           alignment: usesStickySurface ? .center : .topLeading)
            }
        }
    }

    @ViewBuilder
    private var shapeContent: some View {
        let shape = object.shapeKind ?? .roundedRectangle
        switch shape {
        case .circle:
            Circle()
                .fill(fillColor)
                .overlay(Circle().stroke(strokeColor, lineWidth: max(object.style.lineWidth, 1)))
        case .capsule:
            Capsule()
                .fill(fillColor)
                .overlay(Capsule().stroke(strokeColor, lineWidth: max(object.style.lineWidth, 1)))
        case .diamond:
            Diamond()
                .fill(fillColor)
                .overlay(Diamond().stroke(strokeColor, lineWidth: max(object.style.lineWidth, 1)))
        case .rectangle:
            Rectangle()
                .fill(fillColor)
                .overlay(Rectangle().stroke(strokeColor, lineWidth: max(object.style.lineWidth, 1)))
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(strokeColor, lineWidth: max(object.style.lineWidth, 1))
                )
        }
    }

    private var fillColor: Color {
        Color(hex: object.style.fillHex) ?? Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground)
    }

    private var strokeColor: Color {
        if let strokeHex = object.style.strokeHex, let color = Color(hex: strokeHex) {
            return color.opacity(0.55)
        }
        return Color.primary.opacity(0.08)
    }

    private var textColor: Color {
        if let textHex = object.style.textHex, let color = Color(hex: textHex) {
            return color
        }
        return .primary
    }

    private var usesStickySurface: Bool {
        object.kind == .stickyNote || object.kind == .clipNote
    }

    private var usesEditableText: Bool {
        object.kind == .stickyNote || object.kind == .text
    }

    private var noteTags: [ClipTag] {
        Array((object.clip?.tags ?? []).sorted { $0.sortIndex < $1.sortIndex }.prefix(3))
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
