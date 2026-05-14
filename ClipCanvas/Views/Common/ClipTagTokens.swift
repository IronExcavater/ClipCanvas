import SwiftUI

enum TagSelectionState: Equatable {
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

struct ClipTypeTagToken: View {
    let type: ClipType
    let presets: [String]
    let state: TagSelectionState
    let fillsAvailableWidth: Bool

    @State private var colorHex: String

    init(type: ClipType, presets: [String], state: TagSelectionState, fillsAvailableWidth: Bool) {
        self.type = type
        self.presets = presets
        self.state = state
        self.fillsAvailableWidth = fillsAvailableWidth
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
            showsIconInColorCircle: true,
            fillsAvailableWidth: fillsAvailableWidth,
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

struct UserTagToken: View {
    @Bindable var tag: ClipTag

    let presets: [String]
    let state: TagSelectionState
    let isApplyingToClips: Bool
    let isEditing: Bool
    let showsDeleteButton: Bool
    let fillsAvailableWidth: Bool
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
            showsIconInColorCircle: true,
            fillsAvailableWidth: fillsAvailableWidth,
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
    let showsIconInColorCircle: Bool
    let fillsAvailableWidth: Bool
    let onToggle: () -> Void
    let onBeginRename: () -> Void
    let onEndRename: () -> Void
    let onChangeColor: (String) -> Void
    let onDelete: () -> Void

    @FocusState private var nameFocused: Bool

    private var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 9) {
            TagColorPickerButton(
                hex: colorHex,
                icon: showsIconInColorCircle ? icon : nil,
                presets: presets,
                onSelect: onChangeColor
            )

            titleControl

            if state.isActive {
                Image(systemName: state.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
            }

            if showsDeleteButton {
                TagDeleteButton(action: onDelete)
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, showsDeleteButton ? 6 : 12)
        .frame(
            minWidth: fillsAvailableWidth ? nil : 126,
            maxWidth: fillsAvailableWidth ? .infinity : 280,
            minHeight: 48,
            alignment: .leading
        )
        .background(color.opacity(state.isActive ? 0.30 : 0.17), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: primaryAction)
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
        } else {
            titleLabel
        }
    }

    private var titleLabel: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
    }

    private func primaryAction() {
        guard !isEditing else { return }
        if canToggle {
            onToggle()
        } else if canRename {
            onBeginRename()
        }
    }

    @ViewBuilder
    private var contextActions: some View {
        if canToggle {
            Button(state == .selected ? "Remove from Clip" : "Add to Clip", systemImage: "tag", action: onToggle)
        }
        if canRename {
            Button("Rename", systemImage: "pencil", action: onBeginRename)
        }
        if canDelete {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

struct NewTagComposer: View {
    @Binding var name: String
    @Binding var selectedColor: String

    let presets: [String]
    let onCreate: () -> Void

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 9) {
            TagColorPickerButton(
                hex: selectedColor,
                icon: "tag",
                presets: presets,
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(canCreate ? Color.accentColor : Color.primary.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
        }
        .frame(minHeight: 38)
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground), in: Capsule())
        .padding(.bottom, 8)
    }
}

private struct TagColorPickerButton: View {
    let hex: String
    let icon: String?
    let presets: [String]
    let onSelect: (String) -> Void

    @State private var showingPalette = false

    var body: some View {
        Button {
            showingPalette.toggle()
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .accentColor)
                .frame(width: 32, height: 32)
                .overlay {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPalette, arrowEdge: .bottom) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            onSelect(preset)
                            showingPalette = false
                        } label: {
                            Circle()
                                .fill(Color(hex: preset) ?? .accentColor)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if preset == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Change color")
    }
}

private struct TagDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary.opacity(0.62))
                .frame(width: 32, height: 32)
                .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete tag")
    }
}
