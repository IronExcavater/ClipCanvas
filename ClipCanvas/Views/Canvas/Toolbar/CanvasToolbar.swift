import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let selectedCount: Int
    var selectionKind: CanvasSelectionKind = .none
    var isEditing = false
    let onPaste: () -> Void
    let onCreateNote: () -> Void
    let onAskAI: () -> Void
    var onInsertImage: () -> Void = {}
    let onDetails: () -> Void
    let onEditContent: () -> Void
    let onManageTags: () -> Void
    let onArrangeSelection: () -> Void
    let onColor: () -> Void
    let onCopyToClipboard: () -> Void
    let onPasteFromClipboard: () -> Void
    let onFormatBold: () -> Void
    let onFormatItalic: () -> Void
    let onFormatUnderline: () -> Void
    let onFormatStrikethrough: () -> Void
    let onFormatHighlight: (NoteHighlightColor) -> Void
    let onFormatList: (NoteTextListStyle) -> Void
    let onFormatQuote: () -> Void
    let onFormatLink: (String, String?) -> Void
    let onFormatIndent: () -> Void
    let onFormatOutdent: () -> Void
    let onFormatBlockStyle: (NoteTextBlockStyle) -> Void
    let onDelete: () -> Void
    var activeDrawTool: CanvasDrawTool = .pen
    var penColor: PlatformColor = .label
    var highlighterColor: PlatformColor = .systemYellow
    var onCloseMode: () -> Void = {}
    var onDrawTool: (CanvasDrawTool) -> Void = { _ in }
    var onDrawToolSettings: (CanvasDrawTool) -> Void = { _ in }

    @State private var showsFormatPanel = false
    @State private var showsLinkPanel = false
    @State private var linkURL = ""
    @State private var linkDisplayText = ""
    @State private var enabledInlineFormats: Set<CanvasToolbarItem> = []
    @AppStorage(ClipboardService.accessEnabledKey) private var clipboardAccessEnabled = false

    private let buttonSize: CGFloat = 50
    private let iconSize: CGFloat = 19
    private let visiblePagedTools: CGFloat = 6.5

    private var configuration: CanvasToolbarConfiguration {
        CanvasToolbarConfiguration.make(
            selectedCount: selectedCount,
            mode: mode,
            selectionKind: selectionKind,
            isEditing: isEditing
        )
    }

    private var visibleItems: [CanvasToolbarItem] {
        configuration.items.filter { item in
            switch item {
            case .paste, .copyToClipboard, .pasteFromClipboard:
                return clipboardAccessEnabled
            default:
                return true
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            if showsFormatPanel {
                textFormatPanel
            } else if showsLinkPanel {
                linkPanel
            } else {
                toolbarShell
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: showsFormatPanel)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: showsLinkPanel)
    }

    @ViewBuilder
    private var toolbarShell: some View {
        GeometryReader { proxy in
            let maxPanelWidth = max(proxy.size.width, 280)
            let itemCount = visibleItems.count
            let compactWidth = min(maxPanelWidth, CGFloat(itemCount) * buttonSize + CGFloat(max(itemCount - 1, 0)) * 8 + 20)
            let panelWidth = itemCount > 6 ? maxPanelWidth : compactWidth

            HStack {
                Spacer(minLength: 0)
                toolbarContent(width: panelWidth)
                    .frame(width: panelWidth)
                Spacer(minLength: 0)
            }
        }
        .frame(height: buttonSize + 18)
    }

    @ViewBuilder
    private func toolbarContent(width panelWidth: CGFloat) -> some View {
        let isPaged = visibleItems.count > 6
        let contentWidth = max(panelWidth - 20, 1)
        let spacing = isPaged ? max((contentWidth - buttonSize * visiblePagedTools) / visiblePagedTools, 6) : 8

        Group {
            if isPaged {
                pagedToolbar(spacing: spacing)
            } else {
                HStack(spacing: spacing) {
                    ForEach(visibleItems, id: \.self) { item in
                        toolbarItem(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassCapsule(shadow: true, interactive: false)
        .contentShape(Capsule())
        .onTapGesture {}
    }

    private func pagedToolbar(spacing: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: spacing) {
                ForEach(visibleItems, id: \.self) { item in
                    toolbarItem(item)
                        .frame(width: buttonSize)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .frame(height: buttonSize)
    }

    @ViewBuilder
    private func toolbarItem(_ item: CanvasToolbarItem) -> some View {
        let content = Group {
            switch item {
            case .paste: toolButton("clipboard", action: onPaste)
            case .newNote: toolButton("note.text.badge.plus", action: onCreateNote)
            case .insertImage: toolButton("photo.badge.plus", action: onInsertImage)
            case .askAI: toolButton("sparkles", action: onAskAI)
            case .details:
                toolButton("info.circle", action: onDetails)
                    .disabled(selectedCount != 1)
                    .opacity(selectedCount == 1 ? 1 : 0.42)
            case .editContent: toolButton("character.cursor.ibeam", action: onEditContent)
            case .manageTags: toolButton("tag", action: onManageTags)
            case .arrangeSelection: toolButton("square.grid.2x2", action: onArrangeSelection)
            case .duplicate: EmptyView()
            case .color: toolButton("paintpalette", action: onColor)
            case .copyToClipboard: toolButton("doc.on.doc", action: onCopyToClipboard)
            case .pasteFromClipboard: toolButton("doc.on.clipboard", action: onPasteFromClipboard)
            case .formatPanel: toolButton("textformat", action: showFormatPanel)
            case .formatList: listMenu
            case .formatQuote: toolButton("quote.opening", action: onFormatQuote)
            case .formatLink:
                Button(action: showLinkPanel) { toolLabel("link") }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Configure Link", systemImage: "link", action: showLinkPanel)
                    }
            case .formatOutdent: toolButton("decrease.indent", action: onFormatOutdent)
            case .formatIndent: toolButton("increase.indent", action: onFormatIndent)
            case .formatBold: toggleToolButton("bold", item: item, action: onFormatBold)
            case .formatItalic: toggleToolButton("italic", item: item, action: onFormatItalic)
            case .formatUnderline: toggleToolButton("underline", item: item, action: onFormatUnderline)
            case .formatStrikethrough: toggleToolButton("strikethrough", item: item, action: onFormatStrikethrough)
            case .formatHighlight: highlightMenu
            case .delete: destructiveButton("trash", action: onDelete)
            case .divider: AppDivider()
            case .mode(let canvasMode): modeButton(canvasMode.systemImage, for: canvasMode)
            case .closeMode: backToolButton(action: onCloseMode)
            case .drawPen: drawToolButton(.pen)
            case .drawHighlighter: drawToolButton(.highlighter)
            case .drawEraser: drawToolButton(.eraser)
            case .drawLasso: drawToolButton(.lasso)
            }
        }
        .accessibilityLabel(item.label)
        .accessibilityHidden(item == .divider)
        .help(item.label)

        content
    }

    private var listMenu: some View {
        Menu {
            Button("Bulleted", systemImage: "list.bullet") { onFormatList(.bullet) }
            Button("Dashed", systemImage: "list.dash") { onFormatList(.dashed) }
            Button("Numbered", systemImage: "list.number") { onFormatList(.numbered) }
            Button("Checklist", systemImage: "checklist") { onFormatList(.checklist) }
        } label: {
            toolLabel("checklist")
        }
        .buttonStyle(.plain)
    }

    private var highlightMenu: some View {
        Menu {
            ForEach(NoteHighlightColor.allCases, id: \.self) { color in
                Button(color.rawValue.capitalized) {
                    enabledInlineFormats.insert(.formatHighlight)
                    onFormatHighlight(color)
                }
            }
        } label: {
            toolLabel("highlighter", selected: enabledInlineFormats.contains(.formatHighlight))
        }
        .buttonStyle(.plain)
    }

    private func modeButton(_ icon: String, for target: CanvasMode) -> some View {
        Button { mode = target } label: {
            toolLabel(icon, selected: mode == target)
        }
        .buttonStyle(.plain)
    }

    private func toolButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolLabel(icon) }
            .buttonStyle(.plain)
    }

    private func backToolButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "chevron.backward")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func toggleToolButton(_ icon: String, item: CanvasToolbarItem, action: @escaping () -> Void) -> some View {
        Button {
            if enabledInlineFormats.contains(item) {
                enabledInlineFormats.remove(item)
            } else {
                enabledInlineFormats.insert(item)
            }
            action()
        } label: {
            toolLabel(icon, selected: enabledInlineFormats.contains(item))
        }
        .buttonStyle(.plain)
    }

    private func toolLabel(_ icon: String, selected: Bool = false) -> some View {
        ZStack {
            Circle().fill(selected ? Color.accentColor : Color.clear)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .white : .primary)
        }
        .frame(width: buttonSize, height: buttonSize)
        .contentShape(Circle())
    }

    private func drawToolButton(_ tool: CanvasDrawTool) -> some View {
        Button {
            if activeDrawTool == tool, tool.supportsSettings {
                onDrawToolSettings(tool)
            } else {
                onDrawTool(tool)
            }
        } label: {
            ZStack {
                toolLabel(tool.systemImage, selected: activeDrawTool == tool)
                if let color = toolSwatchColor(for: tool) {
                    Circle()
                        .fill(Color(platformColor: color))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.platformSystemBackground, lineWidth: 1))
                        .offset(x: 11, y: 11)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toolSwatchColor(for tool: CanvasDrawTool) -> PlatformColor? {
        switch tool {
        case .pen: return penColor
        case .highlighter: return highlighterColor.withAlphaComponent(1.0)
        default: return nil
        }
    }

    private func destructiveButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) { toolLabel(icon) }
            .buttonStyle(.plain)
    }

    private func showFormatPanel() {
        dismissKeyboard()
        showsFormatPanel = true
    }

    private func showLinkPanel() {
        dismissKeyboard()
        showsLinkPanel = true
    }

    private var textFormatPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Format")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button { showsFormatPanel = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 28) {
                    formatStyleButton("Title", style: .title, font: .title.weight(.bold))
                    formatStyleButton("Heading", style: .heading, font: .title2.weight(.bold))
                    formatStyleButton("Subhead", style: .subheading, font: .headline.weight(.semibold))
                    formatStyleButton("Body", style: .body, font: .body)
                    formatStyleButton("Monostyled", style: .monostyled, font: .body.monospaced())
                }
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
                segmentedFormatButtons
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                listSegment
                indentSegment
                Button(action: onFormatQuote) { toolLabel("quote.opening") }
                    .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 28, shadow: true, interactive: true)
    }

    private func formatStyleButton(_ title: String, style: NoteTextBlockStyle, font: Font) -> some View {
        Button { onFormatBlockStyle(style) } label: {
            Text(title)
                .font(font)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private var segmentedFormatButtons: some View {
        HStack(spacing: 0) {
            Button(action: onFormatBold) { segmentLabel("bold") }
            Button(action: onFormatItalic) { segmentLabel("italic") }
            Button(action: onFormatUnderline) { segmentLabel("underline") }
            Button(action: onFormatStrikethrough) { segmentLabel("strikethrough") }
            highlightMenu
                .frame(width: 48, height: 42)
        }
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .clipShape(Capsule())
    }

    private var listSegment: some View {
        HStack(spacing: 0) {
            Button { onFormatList(.bullet) } label: { segmentLabel("list.bullet") }
            Button { onFormatList(.dashed) } label: { segmentLabel("list.dash") }
            Button { onFormatList(.numbered) } label: { segmentLabel("list.number") }
            Button { onFormatList(.checklist) } label: { segmentLabel("checklist") }
        }
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .clipShape(Capsule())
    }

    private var indentSegment: some View {
        HStack(spacing: 0) {
            Button(action: onFormatOutdent) { segmentLabel("decrease.indent") }
            Button(action: onFormatIndent) { segmentLabel("increase.indent") }
        }
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .clipShape(Capsule())
    }

    private func segmentLabel(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 48, height: 42)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
    }

    private var linkPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Link")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button { showsLinkPanel = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            TextField("URL", text: $linkURL)
                .textFieldStyle(.roundedBorder)
            TextField("Display text", text: $linkDisplayText)
                .textFieldStyle(.roundedBorder)
            Button {
                onFormatLink(linkURL, linkDisplayText.nilIfEmpty)
                linkURL = ""
                linkDisplayText = ""
                showsLinkPanel = false
            } label: {
                Label("Add Link", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .glassPanel(cornerRadius: 28, shadow: true, interactive: true)
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
