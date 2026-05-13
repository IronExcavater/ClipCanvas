import SwiftUI

struct CanvasObjectView: View {
    let object: CanvasObject
    let isSelected: Bool
    var showsContent = true
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    var isEditing = false
    var editingText = ""
    let onCommitEditing: (String) -> Void
    let onResize: (CGSize) -> Void
    let onResizeEnded: () -> Void
    let onToggleExpandedSize: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(14)

            ResizeHandle()
                .onTapGesture(count: 2, perform: onToggleExpandedSize)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { onResize($0.translation) }
                        .onEnded { _ in onResizeEnded() }
                )
        }
        .background {
            if usesStickySurface {
                StickyNoteShape()
                    .fill(fillColor)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fillColor)
            }
        }
        .overlay {
            if usesStickySurface {
                StickyNoteShape()
                    .stroke(isSelected ? Color.accentColor : strokeColor, lineWidth: isSelected ? 2.5 : 1)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : strokeColor, lineWidth: isSelected ? 2.5 : 1)
            }
        }
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08), radius: isSelected ? 10 : 5, y: isSelected ? 4 : 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(perform: onTap)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isSelected)
    }

    @ViewBuilder
    private var content: some View {
        if !showsContent {
            Color.clear
        } else if isEditing, usesEditableText {
            InlineNoteEditor(text: editingText, onCommit: onCommitEditing)
        } else {
            switch object.kind {
            case .image:
                Label(object.text.isEmpty ? "Image" : object.text, systemImage: "photo")
                    .font(.headline)
                    .foregroundStyle(textColor)
            case .shape:
                shapeContent
            case .drawing:
                Label("Drawing", systemImage: "pencil.tip")
                    .font(.headline)
                    .foregroundStyle(textColor)
            case .group:
                Label(object.text.isEmpty ? "Group" : object.text, systemImage: "rectangle.3.group")
                    .font(.headline)
                    .foregroundStyle(textColor)
            default:
                Text(object.displayText.isEmpty ? " " : object.displayText)
                    .font(.system(size: object.style.fontSize))
                    .foregroundStyle(textColor)
                    .lineLimit(nil)
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
        Color(hex: object.style.fillHex) ?? Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground)
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
        object.kind == .stickyNote
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
