import SwiftUI

struct CanvasInspectorPanel: View {
    let selectedObjects: [CanvasObject]
    let detailClip: Clip?
    let activeAIChat: AIChat?
    let onCloseDetail: () -> Void
    let onCloseChat: () -> Void
    let onEdit: () -> Void
    let onDetails: () -> Void
    let onTags: () -> Void
    let onColor: () -> Void
    let onArrange: () -> Void
    let onAskAI: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            if let activeAIChat {
                AIChatDetailView(
                    chat: activeAIChat,
                    selectedCanvasObjectIDs: Set(selectedObjects.map(\.id)),
                    onClose: onCloseChat
                )
            } else if let detailClip {
                ClipDetailView(clip: detailClip, onClose: onCloseDetail)
            } else {
                selectionInspector
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AppGlassSurface(
                shape: .rect(cornerRadius: 0),
                tint: Color.platformSystemBackground.opacity(0.18),
                fallback: .material(.regularMaterial)
            )
        }
    }

    private var selectionInspector: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    selectionSummary
                    actionGrid
                    selectedCards
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .padding(.bottom, 64)
            }
            .navigationTitle(selectionTitle)
            .appInlineNavigationTitleDisplayMode()
        }
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectionSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                metric("rectangle.stack", value: "\(selectedObjects.count)", label: "Cards")
                metric("character.cursor.ibeam", value: "\(textObjectCount)", label: "Text")
                metric("photo", value: "\(imageObjectCount)", label: "Images")
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 10) {
            inspectorAction("Edit", systemImage: "character.cursor.ibeam", isEnabled: selectedObjects.count == 1 && selectedObjects.contains(where: \.canEditTextInInspector), action: onEdit)
            inspectorAction("Details", systemImage: "info.circle", isEnabled: selectedObjects.count == 1, action: onDetails)
            inspectorAction("Tags", systemImage: "tag", isEnabled: selectedObjects.contains { $0.clip != nil }, action: onTags)
            inspectorAction("Color", systemImage: "paintpalette", action: onColor)
            inspectorAction("Arrange", systemImage: "rectangle.3.group", action: onArrange)
            inspectorAction("Ask AI", systemImage: "sparkles", action: onAskAI)
            inspectorAction("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var selectedCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected Cards")
                .font(.subheadline.weight(.semibold))
            ForEach(selectedObjects.prefix(10)) { object in
                AppListRowHeader(
                    systemImage: object.inspectorIcon,
                    color: object.inspectorTint,
                    title: object.inspectorTitle,
                    subtitle: object.inspectorSubtitle,
                    metadata: object.inspectorMetadata,
                    lineLimit: 2,
                    date: object.updatedAt,
                    dateSuffix: " ago"
                )
                .padding(.vertical, 2)
            }

            if selectedObjects.count > 10 {
                Text("+\(selectedObjects.count - 10) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectionTitle: String {
        selectedObjects.count == 1 ? "Selection" : "\(selectedObjects.count) Selected"
    }

    private var selectionSubtitle: String {
        selectedObjects.count == 1
            ? "One canvas card is selected."
            : "Batch actions apply to the selected canvas cards."
    }

    private var textObjectCount: Int {
        selectedObjects.filter { $0.kind == .stickyNote || $0.kind == .text || $0.kind == .clipNote }.count
    }

    private var imageObjectCount: Int {
        selectedObjects.filter { $0.kind == .image || $0.clip?.type == .image }.count
    }

    private func metric(_ icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func inspectorAction(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(role == .destructive ? .red : .primary)
            .frame(maxWidth: .infinity, minHeight: 62)
            .glassPanel(cornerRadius: 16, shadow: false, interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.38)
    }
}

private extension CanvasObject {
    var canEditTextInInspector: Bool {
        switch kind {
        case .stickyNote, .text:
            true
        case .clipNote:
            clip?.type != .image
        default:
            false
        }
    }

    var inspectorTitle: String {
        let text = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        if kind == .image || clip?.type == .image { return "Image" }
        if kind == .drawing { return "Drawing" }
        return "Canvas card"
    }

    var inspectorSubtitle: String? {
        guard let clip else {
            return kind.displayName
        }
        return "\(ClipTag.builtInName(for: clip.type)) - \(clip.origin.label)"
    }

    var inspectorIcon: String {
        if let clip { return clip.type.icon }
        return kind.inspectorIcon
    }

    var inspectorTint: Color {
        clip?.primaryDisplayColor ?? kind.inspectorTint
    }

    var inspectorMetadata: [AppListRowMetadata] {
        var metadata = [
            AppListRowMetadata(kind.inspectorIcon, value: kind.displayName)
        ]
        if !text.isEmpty {
            metadata.append(AppListRowMetadata("character.cursor.ibeam", value: "\(text.count)", monospaced: true))
        }
        return metadata
    }
}

private extension CanvasObjectKind {
    var displayName: String {
        switch self {
        case .stickyNote: "Note"
        case .text: "Text"
        case .clipNote: "Clip"
        case .image: "Image"
        case .drawing: "Drawing"
        case .shape: "Shape"
        case .connector: "Connector"
        case .group: "Group"
        }
    }

    var inspectorIcon: String {
        switch self {
        case .stickyNote: "note.text"
        case .text: "textformat"
        case .clipNote: "doc.text"
        case .image: "photo"
        case .drawing: "scribble.variable"
        case .shape: "square.on.circle"
        case .connector: "point.topleft.down.curvedto.point.bottomright.up"
        case .group: "rectangle.3.group"
        }
    }

    var inspectorTint: Color {
        switch self {
        case .stickyNote, .clipNote: .accentColor
        case .text: .primary
        case .image: .purple
        case .drawing: .orange
        case .shape: .blue
        case .connector: .secondary
        case .group: .green
        }
    }
}
