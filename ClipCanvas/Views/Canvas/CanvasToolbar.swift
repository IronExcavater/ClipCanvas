import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let selectedCount: Int
    var isEditing: Bool = false
    let onPaste: () -> Void
    let onCreateNote: () -> Void
    let onAskAI: () -> Void
    let onTransform: (String) -> Void
    let onDetails: () -> Void
    let onEditContent: () -> Void
    let onManageTags: () -> Void
    let onArrangeSelection: () -> Void
    let onColor: () -> Void
    let onFormatBold: () -> Void
    let onFormatBullet: () -> Void
    let onFormatHighlight: () -> Void
    let onDone: () -> Void
    let onDelete: () -> Void
    var activeDrawTool: CanvasDrawTool = .pen
    var penColor: PlatformColor = .label
    var highlighterColor: PlatformColor = .systemYellow
    var onCloseMode: () -> Void = {}
    var onDrawTool: (CanvasDrawTool) -> Void = { _ in }
    var onDrawToolSettings: (CanvasDrawTool) -> Void = { _ in }

    private var configuration: CanvasToolbarConfiguration {
        CanvasToolbarConfiguration.make(selectedCount: selectedCount, mode: mode, isEditing: isEditing)
    }
    private let buttonSize: CGFloat = 52
    private let iconSize: CGFloat = 19

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(configuration.items.enumerated()), id: \.offset) { _, item in
                        toolbarItem(item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .background { toolbarBackground }
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
            .frame(maxWidth: min(configuration.preferredWidth, 560))
            .contentShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
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
            toolButton("doc.on.clipboard", action: onPaste)
        case .newNote:
            toolButton("square.and.pencil", action: onCreateNote)
        case .askAI:
            toolButton("sparkles", action: onAskAI)
        case .transform:
            transformMenu()
        case .details:
            toolButton("info.circle", action: onDetails)
                .disabled(selectedCount != 1)
                .opacity(selectedCount == 1 ? 1 : 0.42)
        case .editContent:
            toolButton("text.cursor", action: onEditContent)
        case .manageTags:
            toolButton("tag", action: onManageTags)
        case .arrangeSelection:
            toolButton("square.grid.2x2", action: onArrangeSelection)
        case .color:
            toolButton("paintpalette", action: onColor)
        case .formatBold:
            toolButton("bold", action: onFormatBold)
        case .formatBullet:
            toolButton("list.bullet", action: onFormatBullet)
        case .formatHighlight:
            toolButton("highlighter", action: onFormatHighlight)
        case .done:
            doneButton()
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

    private func transformMenu() -> some View {
        Menu {
            ForEach(TextTransformFallbacks.manualEditingOptions) { option in
                Button(option.title, systemImage: option.systemImage) {
                    onTransform(option.id)
                }
            }
        } label: {
            ZStack {
                Color.clear
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Transform")
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
                    Image(systemName: tool.systemImage)
                        .font(.system(size: iconSize - 1, weight: .medium))
                        .foregroundStyle(selected ? .white : .primary)
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

    private func doneButton() -> some View {
        Button(action: onDone) {
            Text("Done")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 14)
                .frame(height: buttonSize)
        }
        .buttonStyle(.plain)
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
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 36))
        } else {
            Capsule().fill(.regularMaterial)
        }
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
