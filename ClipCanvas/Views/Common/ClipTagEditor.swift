import SwiftUI
import SwiftData

struct ClipTagEditor: View {
    let clips: [Clip]

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

            if userTags.isEmpty {
                Text("Create a tag to organize clips.")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: appliesToClips ? 148 : 172), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(userTags) { tag in
                        EditableUserTagToken(
                            tag: tag,
                            presets: presets,
                            state: selectionState(for: tag),
                            isApplyingToClips: appliesToClips,
                            isEditing: editingTagID == tag.id,
                            onTap: { appliesToClips ? toggle(tag) : beginEditing(tag) },
                            onBeginEditing: { beginEditing(tag) },
                            onEndEditing: { finishEditing(tag) },
                            onDelete: { context.delete(tag) }
                        )
                    }
                }
            }

            NewTagComposer(
                name: $newTagName,
                selectedColor: $selectedColor,
                presets: presets,
                onCreate: createTag
            )
        }
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

    private func beginEditing(_ tag: ClipTag) {
        editingTagID = tag.id
    }

    private func finishEditing(_ tag: ClipTag) {
        let trimmed = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.name = trimmed.isEmpty ? "Untitled" : trimmed
        editingTagID = nil
    }
}

private enum TagSelectionState: Equatable {
    case inactive
    case mixed
    case selected

    var isActive: Bool {
        switch self {
        case .inactive: return false
        case .mixed, .selected: return true
        }
    }

    var iconName: String {
        switch self {
        case .inactive: return ""
        case .mixed: return "minus"
        case .selected: return "checkmark"
        }
    }
}

private struct EditableUserTagToken: View {
    @Bindable var tag: ClipTag

    let presets: [String]
    let state: TagSelectionState
    let isApplyingToClips: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tokenControl

            if isEditing {
                HStack(spacing: 10) {
                    ColorPresetGrid(presets: presets, selectedColor: tag.colorHex) { tag.colorHex = $0 }
                    Spacer(minLength: 8)
                    Button(action: onEndEditing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(BlendedIconButtonStyle())
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isEditing)
        .animation(.easeInOut(duration: 0.18), value: state.isActive)
    }

    @ViewBuilder
    private var tokenControl: some View {
        Group {
            if isEditing {
                tokenLabel
            } else {
                Button(action: onTap) {
                    tokenLabel
                }
                .buttonStyle(.plain)
            }
        }
        .onLongPressGesture(perform: onBeginEditing)
        .contextMenu {
            if isApplyingToClips {
                Button(state == .selected ? "Remove from Clip" : "Add to Clip", systemImage: "tag", action: onTap)
            }
            Button("Rename", systemImage: "pencil", action: onBeginEditing)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var tokenLabel: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(tag.color)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(.white.opacity(0.72), lineWidth: 1))

            if isEditing {
                TextField("Tag", text: $tag.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit(onEndEditing)
            } else {
                Text(tag.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if state.isActive {
                Image(systemName: state.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(tag.color, in: Circle())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .padding(.horizontal, 13)
        .background(tag.color.opacity(state.isActive ? 0.30 : 0.17), in: Capsule())
        .contentShape(Capsule())
    }
}

private struct NewTagComposer: View {
    @Binding var name: String
    @Binding var selectedColor: String

    let presets: [String]
    let onCreate: () -> Void

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("New tag", text: $name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit {
                        if canCreate { onCreate() }
                    }

                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .disabled(!canCreate)
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground), in: Capsule())

            ColorPresetGrid(presets: presets, selectedColor: selectedColor) { selectedColor = $0 }
                .padding(.horizontal, 2)
        }
    }
}

struct ColorPresetGrid: View {
    let presets: [String]
    let selectedColor: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 9) {
            ForEach(presets, id: \.self) { hex in
                Button {
                    onSelect(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .accentColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .strokeBorder(selectedColor == hex ? Color.primary.opacity(0.72) : Color.primary.opacity(0.10), lineWidth: selectedColor == hex ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
