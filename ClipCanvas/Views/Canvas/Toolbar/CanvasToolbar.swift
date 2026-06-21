import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let selectedCount: Int
    var selectionKind: CanvasSelectionKind = .none
    var isEditing: Bool = false
    let onPaste: () -> Void
    let onCreateNote: () -> Void
    let onAskAI: () -> Void
    var onInsertImage: () -> Void = {}
    let onDetails: () -> Void
    let onEditContent: () -> Void
    let onManageTags: () -> Void
    let onArrangeSelection: () -> Void
    let onDuplicate: () -> Void
    let onColor: () -> Void
    let onCopyToClipboard: () -> Void
    let onPasteFromClipboard: () -> Void
    let onFormatBold: () -> Void
    let onFormatItalic: () -> Void
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
    private let buttonSize: CGFloat = 44
    private let iconSize: CGFloat = 17

    var body: some View {
        HStack(spacing: 2) {
            ForEach(configuration.items, id: \.self) { item in
                toolbarItem(item)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassCapsule()
        .contentShape(Capsule())
        .onTapGesture {}
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration)
    }

    @ViewBuilder
    private func toolbarItem(_ item: CanvasToolbarItem) -> some View {
        Group {
            switch item {
            case .paste:
                toolButton("clipboard", action: onPaste)
            case .newNote:
                toolButton("note.text.badge.plus", action: onCreateNote)
            case .insertImage:
                toolButton("photo.badge.plus", action: onInsertImage)
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
                toolButton("square.grid.2x2", action: onArrangeSelection)
            case .duplicate:
                toolButton("plus.square.on.square", action: onDuplicate)
            case .color:
                toolButton("paintpalette", action: onColor)
            case .copyToClipboard:
                toolButton("doc.on.doc", action: onCopyToClipboard)
            case .pasteFromClipboard:
                toolButton("doc.on.clipboard", action: onPasteFromClipboard)
            case .formatBold:
                toolButton("bold", action: onFormatBold)
            case .formatItalic:
                toolButton("italic", action: onFormatItalic)
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
        .accessibilityLabel(item.label)
        .accessibilityHidden(item == .divider)
        .help(item.label)
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
                if let color = toolSwatchColor(for: tool) {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(selected ? .white : .primary)
                    Circle()
                        .fill(Color(platformColor: color))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(selected ? Color.white.opacity(0.78) : Color.platformSystemBackground, lineWidth: 1))
                        .offset(x: 11, y: 11)
                } else {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(selected ? .white : .primary)
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

}
