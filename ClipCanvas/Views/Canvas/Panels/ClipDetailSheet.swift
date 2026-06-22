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
    @State private var isTransforming = false
    @State private var isEditingContent = false
    @State private var noteTextCommand: NoteTextCommand?
    @State private var editorHeight: CGFloat = 180
    @ObservedObject private var revealStore = SensitiveTextRevealStore.shared
    var onClose: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ClipDetailActionToolbar(
                        isPinned: clip.isPinned,
                        canOpenLink: ClipActionService.openableURL(for: clip) != nil,
                        canTransform: clip.type != .image,
                        isTransforming: isTransforming,
                        isPrivate: clip.isPrivateContent,
                        onCopy: { ClipActionService.copy(clip) },
                        onOpen: { ClipActionService.openURL(for: clip) },
                        onPin: { ClipActionService.togglePin(clip) },
                        onTransform: applyTransform,
                        onSensitive: { ClipActionService.toggleSensitive(clip) },
                        onEdit: { isEditingContent.toggle() },
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

                    ClipDetailSection("Tags") {
                        ClipTagEditor(clips: [clip], composerShowsShadow: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
            .navigationTitle("Note Details")
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
            ClipInfoRow("Type", value: ClipTag.builtInName(for: clip.type), icon: clip.type.icon)
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

    private var formattingBar: some View {
        HStack(spacing: 8) {
            formatButton("bold", kind: .bold)
            formatButton("italic", kind: .italic)
            formatButton("underline", kind: .underline)
            formatButton("strikethrough", kind: .strikethrough)
            formatButton("list.bullet", kind: .list(.bullet))
            formatButton("highlighter", kind: .highlight(.yellow))
            Spacer(minLength: 0)
            Button("Done", action: onExitEditing)
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
        }
    }

    private func formatButton(_ icon: String, kind: NoteTextCommandKind) -> some View {
        Button { onCommand(kind) } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 16, shadow: false, interactive: true)
        .accessibilityLabel(kind.accessibilityName)
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
        LabeledContent {
            Text(value)
                .foregroundStyle(.primary)
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary.opacity(0.68))
        }
        .font(.footnote)
    }
}

private struct ClipUpdatedRow: View {
    let date: Date

    var body: some View {
        LabeledContent {
            RelativeAgeText(date: date, prefix: "Updated ", suffix: " ago", emptyText: "Updated just now")
                .foregroundStyle(.primary)
        } label: {
            Label("Last Updated", systemImage: "clock")
                .foregroundStyle(.primary.opacity(0.68))
        }
        .font(.footnote)
    }
}

private struct ClipDetailActionToolbar: View {
    let isPinned: Bool
    let canOpenLink: Bool
    let canTransform: Bool
    let isTransforming: Bool
    let isPrivate: Bool
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onPin: () -> Void
    let onTransform: (String) -> Void
    let onSensitive: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                action("Copy", icon: "doc.on.doc", action: onCopy)
                action("Edit", icon: "character.cursor.ibeam", action: onEdit)
                if canOpenLink {
                    action("Open", icon: "safari", action: onOpen)
                }
                transformMenu
                action(isPinned ? "Unpin" : "Pin", icon: isPinned ? "pin.slash" : "pin", action: onPin)
                action(isPrivate ? "Unmark" : "Sensitive",
                       icon: isPrivate ? "lock.open" : "lock",
                       action: onSensitive)
                action("Delete", icon: "trash", destructive: true, action: onDelete)
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
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
        }
        .buttonStyle(.plain)
        .disabled(!canTransform || isTransforming)
    }

    private func action(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(role: destructive ? .destructive : nil, action: action) {
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
        }
        .buttonStyle(.plain)
    }
}

private extension ClipDetailView {
    func updateClipContent(_ text: String) {
        guard clip.content != text else { return }
        let classification = ClipClassificationService.classifySensitivity(text)
        clip.content = text
        clip.type = Clip.detect(content: text, imageData: clip.imageData)
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
                clip.type = Clip.detect(content: text, imageData: clip.imageData)
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
