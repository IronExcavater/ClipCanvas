import SwiftUI
import SwiftData

struct ClipTagEditor: View {
    let clips: [Clip]

    @Environment(\.modelContext) private var context
    @Query(sort: \ClipTag.sortIndex) private var tags: [ClipTag]

    @State private var newTagName = ""
    @State private var selectedColor = "#FF9800"

    private let presets = ["#FF9800", "#4CAF50", "#2196F3", "#9C27B0", "#E91E63", "#607D8B"]
    private var userTags: [ClipTag] { tags.filter { !$0.isBuiltIn } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if clips.count > 1 {
                Text("\(clips.count) clips")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(ClipType.allCases, id: \.self) { type in
                    EditableBuiltInTagChip(
                        type: type,
                        presets: presets,
                        isSelected: clips.allSatisfy { $0.type == type }
                    )
                }

                ForEach(userTags) { tag in
                    EditableUserTagChip(
                        tag: tag,
                        presets: presets,
                        isSelected: clips.allSatisfy { clipHasTag($0, tag) },
                        onToggle: { toggle(tag) }
                    )
                }
            }

            HStack(spacing: 8) {
                TextField("New tag", text: $newTagName)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit(createTag)

                TagColorDot(hex: selectedColor, presets: presets) { selectedColor = $0 }

                Button(action: createTag) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
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
}

private struct EditableBuiltInTagChip: View {
    let type: ClipType
    let presets: [String]
    let isSelected: Bool

    var body: some View {
        EditableTagChip(
            title: ClipTag.builtInName(for: type),
            icon: type.icon,
            hex: ClipTag.builtInHex(for: type),
            presets: presets,
            isSelected: isSelected,
            onSelectColor: { ClipTag.setBuiltInColor($0, for: type) },
            onRename: nil,
            onTap: nil
        )
    }
}

private struct EditableUserTagChip: View {
    @Bindable var tag: ClipTag

    let presets: [String]
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        EditableTagChip(
            title: tag.name,
            icon: "tag",
            hex: tag.colorHex,
            presets: presets,
            isSelected: isSelected,
            onSelectColor: { tag.colorHex = $0 },
            onRename: { tag.name = $0 },
            onTap: onToggle
        )
    }
}

private struct EditableTagChip: View {
    let title: String
    let icon: String
    let hex: String
    let presets: [String]
    let isSelected: Bool
    let onSelectColor: (String) -> Void
    let onRename: ((String) -> Void)?
    let onTap: (() -> Void)?

    @State private var isEditing = false
    @State private var draftTitle = ""

    var body: some View {
        HStack(spacing: 7) {
            TagColorDot(hex: hex, presets: presets, onSelect: onSelectColor)

            if isEditing, onRename != nil {
                TextField("Tag", text: $draftTitle)
                    .font(.subheadline.weight(.semibold))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 64)
                    .onSubmit(commitEdit)
            } else {
                Button(action: { onTap?() }) {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.caption.weight(.semibold))
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
            }

            if isEditing {
                Button(action: commitEdit) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 40)
        .background(Color(hex: hex)?.opacity(isSelected ? 0.30 : 0.16) ?? Color.secondary.opacity(0.14), in: Capsule())
        .contentShape(Capsule())
        .onLongPressGesture {
            if onRename != nil { beginEdit() }
        }
        .contextMenu {
            if onRename != nil {
                Button("Rename Tag", systemImage: "pencil", action: beginEdit)
            }
            if onTap != nil {
                Button(isSelected ? "Remove from Clip" : "Add to Clip", systemImage: "tag", action: { onTap?() })
            }
        }
    }

    private func beginEdit() {
        draftTitle = title
        isEditing = true
    }

    private func commitEdit() {
        if let onRename {
            let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { onRename(trimmed) }
        }
        isEditing = false
    }
}

struct TagColorDot: View {
    let hex: String
    let presets: [String]
    let onSelect: (String) -> Void

    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .accentColor)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPicker, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            ColorPresetGrid(presets: presets, selectedColor: hex) { selected in
                onSelect(selected)
                showingPicker = false
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }
}

struct ColorPresetGrid: View {
    let presets: [String]
    let selectedColor: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { hex in
                Button {
                    onSelect(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .accentColor)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selectedColor == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
