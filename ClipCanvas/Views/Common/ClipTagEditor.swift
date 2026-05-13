import SwiftUI
import SwiftData

struct ClipTagEditor: View {
    let clips: [Clip]
    var showsClipTypes = false

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

            NewTagComposer(
                name: $newTagName,
                selectedColor: $selectedColor,
                presets: presets,
                onCreate: createTag
            )
        }
    }

    private var tagGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 158), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            if showsClipTypes {
                ForEach(ClipType.allCases, id: \.self) { type in
                    ClipTypeTagToken(
                        type: type,
                        presets: presets,
                        state: selectionState(for: type)
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
                    showsDeleteButton: !appliesToClips,
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

private enum TagSelectionState: Equatable {
    case inactive
    case mixed
    case selected

    var isActive: Bool {
        self != .inactive
    }

    var iconName: String {
        switch self {
        case .inactive: return ""
        case .mixed: return "minus"
        case .selected: return "checkmark"
        }
    }
}

private struct ClipTypeTagToken: View {
    let type: ClipType
    let presets: [String]
    let state: TagSelectionState

    @State private var colorHex: String

    init(type: ClipType, presets: [String], state: TagSelectionState) {
        self.type = type
        self.presets = presets
        self.state = state
        _colorHex = State(initialValue: ClipTag.builtInHex(for: type))
    }

    var body: some View {
        EditableTagToken(
            title: ClipTag.builtInName(for: type),
            titleBinding: nil,
            icon: type.icon,
            colorHex: colorHex,
            presets: presets,
            state: state,
            isEditing: false,
            canToggle: false,
            canRename: false,
            canDelete: false,
            showsDeleteButton: false,
            onToggle: {},
            onBeginRename: {},
            onEndRename: {},
            onChangeColor: updateColor,
            onDelete: {}
        )
        .onAppear {
            colorHex = ClipTag.builtInHex(for: type)
        }
    }

    private func updateColor(_ hex: String) {
        colorHex = hex
        ClipTag.setBuiltInColor(hex, for: type)
    }
}

private struct UserTagToken: View {
    @Bindable var tag: ClipTag

    let presets: [String]
    let state: TagSelectionState
    let isApplyingToClips: Bool
    let isEditing: Bool
    let showsDeleteButton: Bool
    let onToggle: () -> Void
    let onBeginRename: () -> Void
    let onEndRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        EditableTagToken(
            title: tag.name,
            titleBinding: $tag.name,
            icon: "tag",
            colorHex: tag.colorHex,
            presets: presets,
            state: state,
            isEditing: isEditing,
            canToggle: isApplyingToClips,
            canRename: true,
            canDelete: true,
            showsDeleteButton: showsDeleteButton,
            onToggle: onToggle,
            onBeginRename: onBeginRename,
            onEndRename: onEndRename,
            onChangeColor: { tag.colorHex = $0 },
            onDelete: onDelete
        )
    }
}

private struct EditableTagToken: View {
    let title: String
    let titleBinding: Binding<String>?
    let icon: String
    let colorHex: String
    let presets: [String]
    let state: TagSelectionState
    let isEditing: Bool
    let canToggle: Bool
    let canRename: Bool
    let canDelete: Bool
    let showsDeleteButton: Bool
    let onToggle: () -> Void
    let onBeginRename: () -> Void
    let onEndRename: () -> Void
    let onChangeColor: (String) -> Void
    let onDelete: () -> Void

    @State private var showingColorPicker = false
    @FocusState private var nameFocused: Bool

    private var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 9) {
            TagColorPickerButton(
                hex: colorHex,
                presets: presets,
                isPresented: $showingColorPicker,
                onSelect: onChangeColor
            )

            titleControl

            if state.isActive {
                Image(systemName: state.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 20, height: 20)
            }

            if showsDeleteButton {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.56))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete tag")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .padding(.leading, 12)
        .padding(.trailing, showsDeleteButton ? 8 : 12)
        .background(color.opacity(state.isActive ? 0.30 : 0.17), in: Capsule())
        .contentShape(Capsule())
        .contextMenu { contextActions }
        .onChange(of: isEditing) { _, editing in
            if editing { nameFocused = true }
        }
        .animation(.easeInOut(duration: 0.18), value: isEditing)
        .animation(.easeInOut(duration: 0.18), value: state)
    }

    @ViewBuilder
    private var titleControl: some View {
        if isEditing, let titleBinding {
            TextField("Tag", text: titleBinding)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit(onEndRename)
        } else if canToggle {
            Button(action: onToggle) {
                titleLabel
            }
            .buttonStyle(.plain)
        } else {
            titleLabel
        }
    }

    private var titleLabel: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var contextActions: some View {
        if canToggle {
            Button(state == .selected ? "Remove from Clip" : "Add to Clip", systemImage: "tag", action: onToggle)
        }
        Button("Change Color", systemImage: "paintpalette") {
            showingColorPicker = true
        }
        if canRename {
            Button("Rename", systemImage: "pencil", action: onBeginRename)
        }
        if canDelete {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

private struct NewTagComposer: View {
    @Binding var name: String
    @Binding var selectedColor: String

    let presets: [String]
    let onCreate: () -> Void

    @State private var showingColorPicker = false

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            TagColorPickerButton(
                hex: selectedColor,
                presets: presets,
                isPresented: $showingColorPicker
            ) { selectedColor = $0 }

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
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(BlendedIconButtonStyle())
            .disabled(!canCreate)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground), in: Capsule())
    }
}

private struct TagColorPickerButton: View {
    let hex: String
    let presets: [String]
    @Binding var isPresented: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .accentColor)
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white.opacity(0.76), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            ColorPresetGrid(presets: presets, selectedColor: hex) { selected in
                onSelect(selected)
                isPresented = false
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Change color")
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
