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

    private static let maxNameLength = 30

    @ViewBuilder
    private var titleControl: some View {
        if isEditing, let titleBinding {
            HStack(spacing: 6) {
                TextField("Tag", text: titleBinding)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit(onEndRename)
                    .onChange(of: titleBinding.wrappedValue) { _, newValue in
                        if newValue.count > Self.maxNameLength {
                            titleBinding.wrappedValue = String(newValue.prefix(Self.maxNameLength))
                        }
                    }

                let remaining = Self.maxNameLength - titleBinding.wrappedValue.count
                if remaining <= 8 {
                    Text("\(remaining)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(remaining <= 3 ? .red : .secondary)
                        .monospacedDigit()
                }
            }
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

