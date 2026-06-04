import SwiftUI
import SwiftData

enum ClipTagEditorLayout {
    case flow
    case twoColumns
}

struct ClipTagEditor: View {
    let clips: [Clip]
    var showsClipTypes = false
    var layout: ClipTagEditorLayout = .twoColumns
    var composerShowsShadow = false

    @Environment(\.modelContext) private var context
    @Query(sort: \ClipTag.sortIndex) private var tags: [ClipTag]

    @State private var newTagName = ""
    @State private var selectedColor = "#FF9800"
    @State private var editingTagID: UUID?

    private let presets = ["#FF9800", "#4CAF50", "#2196F3", "#9C27B0", "#E91E63", "#607D8B"]
    private var userTags: [ClipTag] { tags.filter { !$0.isBuiltIn } }
    private var appliesToClips: Bool { !clips.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if clips.count > 1 {
                Text("\(clips.count) clips selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            tagGrid

            TagComposer(
                name: $newTagName,
                selectedColor: $selectedColor,
                presets: presets,
                showsShadow: composerShowsShadow,
                onCreate: createTag
            )
        }
    }

    private var tagGrid: some View {
        Group {
            switch layout {
            case .flow:
                TagFlowLayout(spacing: 8, rowSpacing: 8) {
                    tagTokens(fillsAvailableWidth: false)
                }
            case .twoColumns:
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    tagTokens(fillsAvailableWidth: true)
                }
            }
        }
    }

    @ViewBuilder
    private func tagTokens(fillsAvailableWidth: Bool) -> some View {
        if showsClipTypes {
            ForEach(ClipType.allCases, id: \.self) { type in
                ClipTypeTagToken(
                    type: type,
                    presets: presets,
                    state: selectionState(for: type),
                    fillsAvailableWidth: fillsAvailableWidth
                )
            }
        }

        ForEach(userTags) { tag in
            UserTagToken(
                tag: tag,
                presets: presets,
                state: selectionState(for: tag),
                isApplyingToClips: appliesToClips,
                isEditing: editingTagID == tag.id,
                showsDeleteButton: !appliesToClips && editingTagID != tag.id,
                fillsAvailableWidth: fillsAvailableWidth,
                onToggle: { toggle(tag) },
                onBeginRename: { editingTagID = tag.id },
                onEndRename: { finishEditing(tag) },
                onDelete: { context.delete(tag) }
            )
        }

        if userTags.isEmpty && !showsClipTypes {
            Text("Create a tag to organize clips.")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
    }

    private func selectionState(for type: ClipType) -> TagSelectionState {
        guard appliesToClips else { return .inactive }
        let count = clips.filter { $0.type == type }.count
        if count == clips.count { return .selected }
        if count > 0 { return .mixed }
        return .inactive
    }

    private func selectionState(for tag: ClipTag) -> TagSelectionState {
        guard appliesToClips else { return .inactive }
        let taggedCount = clips.filter { clipHasTag($0, tag) }.count
        if taggedCount == clips.count { return .selected }
        if taggedCount > 0 { return .mixed }
        return .inactive
    }

    private func clipHasTag(_ clip: Clip, _ tag: ClipTag) -> Bool {
        clip.tags.contains { $0.id == tag.id }
    }

    private func toggle(_ tag: ClipTag) {
        let remove = clips.allSatisfy { clipHasTag($0, tag) }
        for clip in clips {
            if remove {
                clip.tags.removeAll { $0.id == tag.id }
            } else if !clipHasTag(clip, tag) {
                clip.tags.append(tag)
            }
        }
    }

    private func createTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let sortIndex = (tags.map(\.sortIndex).max() ?? 10) + 1
        let tag = ClipTag(name: trimmed, colorHex: selectedColor, isBuiltIn: false, sortIndex: sortIndex)
        context.insert(tag)
        for clip in clips where !clipHasTag(clip, tag) {
            clip.tags.append(tag)
        }
        newTagName = ""
    }

    private func finishEditing(_ tag: ClipTag) {
        let trimmed = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.name = trimmed.isEmpty ? "Untitled" : trimmed
        editingTagID = nil
    }
}
