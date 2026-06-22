import SwiftData
import SwiftUI

struct ClipDetailSheet: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ClipDetailView(clip: clip, onClose: { dismiss() })
            .appSheetPresentationDetents()
    }
}

struct ClipDetailView: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }, sort: \Workspace.sortIndex)
    private var workspaces: [Workspace]
    @State private var isTransforming = false
    @State private var isEditingContent = false
    @State private var noteTextCommand: NoteTextCommand?
    @State private var editorHeight: CGFloat = 180
    @AppStorage(ClipboardService.accessEnabledKey) private var clipboardAccessEnabled = false
    @ObservedObject private var revealStore = SensitiveTextRevealStore.shared
    var onClose: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ClipDetailActionToolbar(
                        isPinned: clip.isPinned,
                        canOpenLink: ClipActionService.openableURL(for: clip) != nil,
                        canEdit: clip.type != .image,
                        canTransform: clip.type != .image,
                        isTransforming: isTransforming,
                        isPrivate: clip.isPrivateContent,
                        canChangeSensitivity: clip.isPrivateContent || ClipClassificationService.canMarkSensitiveMarkdown(in: clip.content),
                        canCopy: clipboardAccessEnabled,
                        shareText: shareText,
                        canAddToCanvas: activeWorkspace != nil,
                        onCopy: { _ = ClipActionService.copy(clip) },
                        onOpen: { ClipActionService.openURL(for: clip) },
                        onPin: { ClipActionService.togglePin(clip) },
                        onTransform: applyTransform,
                        onSensitive: { ClipActionService.toggleSensitive(clip) },
                        onEdit: { isEditingContent.toggle() },
                        onAddToCanvas: addToCanvas,
                        onDelete: {
                            ClipActionService.softDelete(clip)
                            close()
                        }
                    )

                    ClipDetailSection("Content") {
                        ClipContentPanel(
                            clip: clip,
                            revealedSensitiveParts: revealStore.revealedPartIDs,
                            isEditing: isEditingContent,
                            command: noteTextCommand,
                            editorHeight: editorHeight,
                            onEditorHeightChange: { editorHeight = $0 },
                            onCommit: updateClipContent,
                            onExitEditing: { isEditingContent = false },
                            onCommand: { noteTextCommand = NoteTextCommand(kind: $0) },
                            onSensitivePartTapped: revealStore.toggle
                        )
                    }

                    ClipDetailSection("Info") {
                        ClipInfoPanel(clip: clip)
                    }

                    if !canvasObjects.isEmpty {
                        ClipDetailSection("Note Color") {
                            CanvasColorPanel(objects: canvasObjects, onDismiss: {})
                        }
                    }

                    ClipDetailSection("Tags") {
                        ClipTagEditor(clips: [clip], composerShowsShadow: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
            .navigationTitle("Details")
            .appInlineNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) {
                        AppCircleIconLabel(systemImage: "xmark", size: 36, symbolSize: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            .appScrollDismissesKeyboardInteractively()
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var canvasObjects: [CanvasObject] {
        clip.canvasObjects
            .filter(\.isCanvasContent)
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt { return lhs.createdAt < rhs.createdAt }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var shareText: String {
        if clip.type == .image {
            return clip.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ClipCanvas image" : clip.content
        }
        return clip.content
    }
}

private struct ClipDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            content
        }
    }
}

private struct ClipInfoPanel: View {
    let clip: Clip

    var body: some View {
        VStack(spacing: 7) {
            ClipTypePickerRow(clip: clip)
            ClipInfoRow("Privacy", value: privacyLabel, icon: privacyIcon)
            if let expiresAt = clip.expiresAt, clip.isPrivateContent {
                ClipInfoRow("Expires", value: expiresAt.formatted(date: .omitted, time: .shortened), icon: "timer")
            }
            ClipUpdatedRow(date: clip.updatedAt)
            ClipInfoRow("Created", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyLabel: String {
        switch clip.sensitivity {
        case .normal:
            return "Normal"
        case .sensitive:
            return "Sensitive"
        case .privateContent:
            return "Hidden"
        }
    }

    private var privacyIcon: String {
        clip.isPrivateContent ? "lock.fill" : "hand.raised"
    }
}

private struct ClipTypePickerRow: View {
    let clip: Clip

    var body: some View {
        HStack(spacing: 12) {
            Label("Type", systemImage: clip.type.icon)
                .foregroundStyle(.primary.opacity(0.68))

            Spacer(minLength: 12)

            Picker("Type", selection: typeBinding) {
                ForEach(availableTypes, id: \.self) { type in
                    Label(ClipTag.builtInName(for: type), systemImage: type.icon)
                        .tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if clip.isTypeManuallySet {
                Button("Auto") {
                    clip.resetTypeDetection()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
        .font(.footnote)
    }

    private var typeBinding: Binding<ClipType> {
        Binding(
            get: { clip.type },
            set: { clip.setManualType($0) }
        )
    }

    private var availableTypes: [ClipType] {
        clip.imageData == nil ? [.text, .url, .code] : ClipType.allCases
    }
}

private struct ClipContentPanel: View {
    let clip: Clip
    let revealedSensitiveParts: Set<String>
    let isEditing: Bool
    let command: NoteTextCommand?
    let editorHeight: CGFloat
    let onEditorHeightChange: (CGFloat) -> Void
    let onCommit: (String) -> Void
    let onExitEditing: () -> Void
    let onCommand: (NoteTextCommandKind) -> Void
    let onSensitivePartTapped: (String) -> Void
    @State private var activeHighlight: NoteHighlightColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if clip.type == .image {
                ClipDetailImagePreview(clip: clip)
            } else if isEditing {
                formattingBar
                NoteTextEditor(
                    initialText: clip.content,
                    fontSize: 16,
                    command: command,
                    onCommit: onCommit,
                    onExitEditing: onExitEditing,
                    onSizeChange: { size in
                        onEditorHeightChange((size.height + 18).clamped(to: 140...420))
                    }
                )
                .frame(minHeight: editorHeight, maxHeight: editorHeight)
                if showsEditorPreview {
                    MarkdownPreview(text: clip.content)
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.76))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                MarkdownPreview(
                    text: clip.displayPreview(isRevealed: false),
                    emptyText: "No text",
                    revealedSensitiveParts: revealedSensitiveParts,
                    onSensitivePartTapped: onSensitivePartTapped
                )
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsEditorPreview: Bool {
        let text = clip.content
        return text.contains("\n- ")
            || text.contains("\n* ")
            || text.contains("\n• ")
            || text.contains("\n1. ")
            || text.contains("**")
            || text.contains("==")
            || text.contains("[")
    }

    private var formattingBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                blockStyleMenu
                listMenu
                formatButton("quote.opening", kind: .quote)
                formatButton("decrease.indent", kind: .outdent)
                formatButton("increase.indent", kind: .indent)
                formatButton("bold", kind: .bold)
                formatButton("italic", kind: .italic)
                formatButton("underline", kind: .underline)
                formatButton("strikethrough", kind: .strikethrough)
                highlightMenu
                Spacer(minLength: 0)
                Button("Done", action: onExitEditing)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var blockStyleMenu: some View {
        Menu {
            Button("Title") { onCommand(.blockStyle(.title)) }
            Button("Heading") { onCommand(.blockStyle(.heading)) }
            Button("Subheading") { onCommand(.blockStyle(.subheading)) }
            Button("Body") { onCommand(.blockStyle(.body)) }
            Button("Monostyled") { onCommand(.blockStyle(.monostyled)) }
        } label: {
            formatLabel("textformat")
        }
        .buttonStyle(.plain)
    }

    private var listMenu: some View {
        Menu {
            Button("Bulleted", systemImage: "list.bullet") { onCommand(.list(.bullet)) }
            Button("Dashed", systemImage: "list.dash") { onCommand(.list(.dashed)) }
            Button("Numbered", systemImage: "list.number") { onCommand(.list(.numbered)) }
            Button("Checklist", systemImage: "checklist") { onCommand(.list(.checklist)) }
        } label: {
            formatLabel("checklist")
        }
        .buttonStyle(.plain)
    }

    private var highlightMenu: some View {
        Menu {
            ForEach(NoteHighlightColor.allCases, id: \.self) { color in
                Button(color.rawValue.capitalized) {
                    activeHighlight = color
                    onCommand(.highlight(color))
                }
            }
        } label: {
            formatLabel("highlighter", isActive: activeHighlight != nil, activeTint: .orange)
        }
        .buttonStyle(.plain)
    }

    private func formatButton(_ icon: String, kind: NoteTextCommandKind) -> some View {
        Button { onCommand(kind) } label: {
            formatLabel(icon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.accessibilityName)
    }

    private func formatLabel(_ icon: String, isActive: Bool = false, activeTint: Color = .accentColor) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isActive ? .white : .primary)
            .frame(width: 34, height: 34)
            .background(isActive ? activeTint : Color.secondary.opacity(0.10), in: Circle())
            .contentShape(Circle())
    }
}

private struct ClipDetailImagePreview: View {
    let clip: Clip

    var body: some View {
        Group {
            if let data = clip.imageData, let image = PlatformImage(data: data) {
                platformImage(image)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 180, maxHeight: 420)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            } else {
                Label("Image unavailable", systemImage: "photo")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
    }

    @ViewBuilder
    private func platformImage(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
        #endif
    }
}

private struct ClipInfoRow: View {
    let title: String
    let value: String
    let icon: String

    init(_ title: String, value: String, icon: String) {
        self.title = title
        self.value = value
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary.opacity(0.68))
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.footnote)
    }
}

private struct ClipUpdatedRow: View {
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
            Label("Last Updated", systemImage: "clock")
                .foregroundStyle(.primary.opacity(0.68))
            Spacer(minLength: 12)
            RelativeAgeText(date: date, prefix: "Updated ", suffix: " ago", emptyText: "Updated just now")
                .foregroundStyle(.primary)
        }
        .font(.footnote)
    }
}

private struct ClipDetailActionToolbar: View {
    let isPinned: Bool
    let canOpenLink: Bool
    let canEdit: Bool
    let canTransform: Bool
    let isTransforming: Bool
    let isPrivate: Bool
    let canChangeSensitivity: Bool
    let canCopy: Bool
    let shareText: String
    let canAddToCanvas: Bool
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onPin: () -> Void
    let onTransform: (String) -> Void
    let onSensitive: () -> Void
    let onEdit: () -> Void
    let onAddToCanvas: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
            action("Copy", icon: "doc.on.doc", action: onCopy)
                .disabled(!canCopy)
            ShareLink(item: shareText) {
                actionLabel("Share", icon: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            if canEdit {
                action("Edit", icon: "character.cursor.ibeam", action: onEdit)
            }
            if canOpenLink {
                action("Open", icon: "safari", action: onOpen)
            }
            action("Canvas", icon: "square.and.arrow.down", action: onAddToCanvas)
                .disabled(!canAddToCanvas)
            transformMenu
            action(isPinned ? "Unpin" : "Pin", icon: isPinned ? "pin.slash" : "pin", action: onPin)
            if canChangeSensitivity {
                action(isPrivate ? "Unmark" : "Sensitive",
                       icon: isPrivate ? "lock.open" : "lock",
                       action: onSensitive)
            }
            action("Delete", icon: "trash", destructive: true, action: onDelete)
        }
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 68, maximum: 86), spacing: 10)]
    }

    @ViewBuilder
    private var transformMenu: some View {
        Menu {
            Button("Clean Up") { onTransform("clip.cleanUp") }
            Button("Distill") { onTransform("clip.distill") }
            Button("Action Items") { onTransform("clip.actionItems") }
            Button("Rewrite") { onTransform("clip.rewrite") }
            Button("Title") { onTransform("clip.title") }
        } label: {
            VStack(spacing: 5) {
                if isTransforming {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text("Transform")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.primary)
            .frame(width: 68, height: 58)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canTransform || isTransforming)
    }

    private func action(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            actionLabel(title, icon: icon, destructive: destructive)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, icon: String, destructive: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(destructive ? .red : .primary)
        .frame(width: 68, height: 58)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension ClipDetailView {
    func addToCanvas() {
        activeWorkspace?.placeDuplicate(of: clip, in: context)
    }

    func updateClipContent(_ text: String) {
        guard clip.content != text else { return }
        let classification = ClipClassificationService.classifySensitivity(text)
        clip.content = text
        clip.updateDetectedType()
        clip.updateSensitivity(classification.sensitivity, reason: classification.reason)
        clip.updatedAt = Date()
    }

    func applyTransform(_ skillID: String) {
        guard !isTransforming, clip.type != .image else { return }
        let input = TransformSkillInput(
            clipIDs: [clip.id],
            text: clip.content
        )
        isTransforming = true
        Task {
            defer { isTransforming = false }
            do {
                let result = try await TransformSkillRegistry().run(skillID, input: input)
                guard let text = result.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { return }
                let classification = ClipClassificationService.classifySensitivity(text)
                clip.content = text
                clip.updateDetectedType()
                clip.updateSensitivity(classification.sensitivity, reason: classification.reason)
                clip.updatedAt = Date()
            } catch {
                // Keep the existing clip unchanged when a transform fails.
            }
        }
    }
}

private extension NoteTextCommandKind {
    var accessibilityName: String {
        switch self {
        case .blockStyle(let style): style.rawValue.capitalized
        case .bold: "Bold"
        case .italic: "Italic"
        case .underline: "Underline"
        case .strikethrough: "Strikethrough"
        case .highlight: "Highlight"
        case .list(let style): "\(style.rawValue.capitalized) List"
        case .quote: "Quote"
        case .link: "Link"
        case .indent: "Indent"
        case .outdent: "Outdent"
        }
    }
}
