import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let selectedCount: Int
    var selectionKind: CanvasSelectionKind = .none
    var isEditing: Bool = false
    let onPaste: () -> Void
    let onCreateNote: () -> Void
    let onAskAI: () -> Void
    let onDetails: () -> Void
    let onEditContent: () -> Void
    let onManageTags: () -> Void
    let onArrangeSelection: () -> Void
    let onColor: () -> Void
    let onFormatBold: () -> Void
    let onFormatBullet: () -> Void
    let onFormatHighlight: () -> Void
    let onDelete: () -> Void
    var activeDrawTool: CanvasDrawTool = .pen
    var penColor: PlatformColor = .label
    var highlighterColor: PlatformColor = .systemYellow
    var onCloseMode: () -> Void = {}
    var onDrawTool: (CanvasDrawTool) -> Void = { _ in }
    var onDrawToolSettings: (CanvasDrawTool) -> Void = { _ in }

    private var configuration: CanvasToolbarConfiguration {
        CanvasToolbarConfiguration.make(
            selectedCount: selectedCount,
            mode: mode,
            selectionKind: selectionKind,
            isEditing: isEditing
        )
    }
    private let buttonSize: CGFloat = 46
    private let iconSize: CGFloat = 18
    private let stableToolbarWidth: CGFloat = 326

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(Array(configuration.items.enumerated()), id: \.offset) { _, item in
                    toolbarItem(item)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: stableToolbarWidth)
            .background { toolbarBackground }
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
            .contentShape(Capsule())
            .onTapGesture {}
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration)
    }

    @ViewBuilder
    private func toolbarItem(_ item: CanvasToolbarItem) -> some View {
        switch item {
        case .paste:
            toolButton("clipboard", action: onPaste)
        case .newNote:
            toolButton("note.text.badge.plus", action: onCreateNote)
        case .askAI:
            toolButton("sparkles", action: onAskAI)
        case .details:
            toolButton("info.circle", action: onDetails)
                .disabled(selectedCount != 1)
                .opacity(selectedCount == 1 ? 1 : 0.42)
        case .editContent:
            toolButton("character.cursor.ibeam", action: onEditContent)
        case .manageTags:
            toolButton("tag", action: onManageTags)
        case .arrangeSelection:
            toolButton("rectangle.3.group", action: onArrangeSelection)
        case .color:
            toolButton("paintpalette", action: onColor)
        case .formatBold:
            toolButton("bold", action: onFormatBold)
        case .formatBullet:
            toolButton("list.bullet", action: onFormatBullet)
        case .formatHighlight:
            toolButton("highlighter", action: onFormatHighlight)
        case .delete:
            destructiveButton("trash", action: onDelete)
        case .divider:
            AppDivider()
        case .mode(let canvasMode):
            modeButton(canvasMode.systemImage, for: canvasMode)
        case .closeMode:
            toolButton("xmark", action: onCloseMode)
        case .drawPen:
            drawToolButton(.pen)
        case .drawHighlighter:
            drawToolButton(.highlighter)
        case .drawEraser:
            drawToolButton(.eraser)
        case .drawLasso:
            drawToolButton(.lasso)
        }
    }

    private func modeButton(_ icon: String, for target: CanvasMode) -> some View {
        Button { mode = target } label: {
            let selected = mode == target
            ZStack {
                Circle().fill(selected ? Color.accentColor : Color.clear)
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(selected ? .white : .primary)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
            .shadow(
                color: selected ? Color.accentColor.opacity(0.28) : .clear,
                radius: selected ? 9 : 0,
                y: selected ? 4 : 0
            )
            .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: mode == target)
    }

    private func toolButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Color.clear
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func drawToolButton(_ tool: CanvasDrawTool) -> some View {
        Button {
            if activeDrawTool == tool, tool.supportsSettings {
                onDrawToolSettings(tool)
            } else {
                onDrawTool(tool)
            }
        } label: {
            let selected = activeDrawTool == tool
            ZStack {
                Circle().fill(selected ? Color.accentColor : Color.clear)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    PencilKitToolGlyph(
                        tool: tool,
                        color: toolSwatchColor(for: tool),
                        isSelected: selected
                    )
                    .frame(width: 25, height: 25)
                    Spacer(minLength: 0)
                    if let color = toolSwatchColor(for: tool) {
                        Capsule()
                            .fill(Color(platformColor: color))
                            .frame(width: 16, height: 3)
                            .padding(.bottom, 7)
                    } else {
                        Spacer().frame(height: 10)
                    }
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
            .shadow(
                color: selected ? Color.accentColor.opacity(0.24) : .clear,
                radius: selected ? 8 : 0,
                y: selected ? 3 : 0
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: activeDrawTool == tool)
    }

    private func toolSwatchColor(for tool: CanvasDrawTool) -> PlatformColor? {
        switch tool {
        case .pen: return penColor
        case .highlighter: return highlighterColor.withAlphaComponent(1.0)
        default: return nil
        }
    }

    private func destructiveButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            ZStack {
                Color.clear
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var toolbarBackground: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.regularMaterial)
        }
    }
}

private struct PencilKitToolGlyph: View {
    let tool: CanvasDrawTool
    let color: PlatformColor?
    let isSelected: Bool

    private var strokeColor: Color {
        isSelected ? .white : .primary
    }

    private var fillColor: Color {
        if let color {
            return Color(platformColor: color)
        }
        return isSelected ? .white.opacity(0.92) : .primary.opacity(0.78)
    }

    var body: some View {
        Canvas { context, size in
            switch tool {
            case .pen:
                drawPen(in: &context, size: size)
            case .highlighter:
                drawHighlighter(in: &context, size: size)
            case .eraser:
                drawEraser(in: &context, size: size)
            case .lasso:
                drawLasso(in: &context, size: size)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawPen(in context: inout GraphicsContext, size: CGSize) {
        let body = Path { path in
            path.move(to: CGPoint(x: size.width * 0.72, y: size.height * 0.10))
            path.addLine(to: CGPoint(x: size.width * 0.89, y: size.height * 0.27))
            path.addLine(to: CGPoint(x: size.width * 0.32, y: size.height * 0.84))
            path.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.92))
            path.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.74))
            path.closeSubpath()
        }
        context.fill(body, with: .color(fillColor))
        context.stroke(body, with: .color(strokeColor.opacity(0.78)), lineWidth: 1.2)
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.60, y: size.height * 0.22))
                path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.40))
            },
            with: .color(strokeColor.opacity(0.9)),
            lineWidth: 1.2
        )
    }

    private func drawHighlighter(in context: inout GraphicsContext, size: CGSize) {
        let body = Path { path in
            path.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.18))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.18))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.68))
            path.addLine(to: CGPoint(x: size.width * 0.60, y: size.height * 0.86))
            path.addLine(to: CGPoint(x: size.width * 0.40, y: size.height * 0.86))
            path.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.68))
            path.closeSubpath()
        }
        context.fill(body, with: .color(fillColor.opacity(isSelected ? 0.95 : 0.82)))
        context.stroke(body, with: .color(strokeColor.opacity(0.62)), lineWidth: 1.1)
        let tip = Path { path in
            path.move(to: CGPoint(x: size.width * 0.34, y: size.height * 0.72))
            path.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.72))
            path.addLine(to: CGPoint(x: size.width * 0.58, y: size.height * 0.90))
            path.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.90))
            path.closeSubpath()
        }
        context.fill(tip, with: .color(strokeColor.opacity(isSelected ? 0.88 : 0.72)))
    }

    private func drawEraser(in context: inout GraphicsContext, size: CGSize) {
        let eraser = Path { path in
            path.move(to: CGPoint(x: size.width * 0.58, y: size.height * 0.10))
            path.addLine(to: CGPoint(x: size.width * 0.90, y: size.height * 0.42))
            path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height * 0.86))
            path.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.54))
            path.closeSubpath()
        }
        context.fill(eraser, with: .color(isSelected ? .white.opacity(0.94) : Color.platformSystemBackground.opacity(0.95)))
        context.stroke(eraser, with: .color(strokeColor.opacity(0.76)), lineWidth: 1.2)
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.30, y: size.height * 0.70))
                path.addLine(to: CGPoint(x: size.width * 0.76, y: size.height * 0.24))
            },
            with: .color(strokeColor.opacity(0.45)),
            lineWidth: 1
        )
    }

    private func drawLasso(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: size.width * 0.12,
            y: size.height * 0.16,
            width: size.width * 0.72,
            height: size.height * 0.58
        ))
        context.stroke(path, with: .color(strokeColor.opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.66, y: size.height * 0.66))
                path.addLine(to: CGPoint(x: size.width * 0.88, y: size.height * 0.88))
            },
            with: .color(strokeColor.opacity(0.9)),
            lineWidth: 2
        )
    }
}

struct CanvasUndoControls: View {
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            undoButton("arrow.uturn.backward", action: onUndo)
            undoButton("arrow.uturn.forward", action: onRedo)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .frame(width: 44)
        .padding(.vertical, 6)
        .background { undoBackground }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func undoButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
    }

    @ViewBuilder
    private var undoBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            Capsule().fill(.regularMaterial)
        }
    }
}

struct CanvasZoomControls: View {
    let scale: CGFloat
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                zoomButton("plus", action: onZoomIn)
                zoomButton("minus", action: onZoomOut)
            }
            Text("\(Int((scale * 100).rounded()))%")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .frame(width: 44)
        .padding(.vertical, 5)
        .background { zoomBackground }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func zoomButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
    }

    @ViewBuilder
    private var zoomBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            Capsule().fill(.regularMaterial)
        }
    }
}
