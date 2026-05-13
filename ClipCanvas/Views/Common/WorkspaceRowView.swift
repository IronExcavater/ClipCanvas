import SwiftUI

struct WorkspaceRowView: View {
    let workspace: Workspace
    let isRenaming: Bool
    @Binding var editingName: String
    var isSelecting = false
    var isSelected = false
    let onActivate: () -> Void
    let onRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        AppListItemButton(tint: .secondary, opacity: workspace.isActive ? 0.16 : 0.12, action: onActivate) {
            rowContent
                .frame(minHeight: 58)
                .appListItemContentPadding(horizontal: 10, vertical: 8)
        }
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: onRename)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .onChange(of: isRenaming) { _, newValue in
            if newValue { focused = true }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                if isRenaming {
                    TextField("Workspace name", text: $editingName)
                        .font(.subheadline.weight(.semibold))
                        .focused($focused)
                        .onSubmit(onCommitRename)
                        .onDisappear(perform: onCommitRename)
                } else {
                    Text(workspace.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 4) {
                    Text(cardCountText)
                    Spacer(minLength: 6)
                    RelativeAgeText(date: workspace.updatedAt, prefix: "Updated ", suffix: " ago")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            if workspace.isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var cardCountText: String {
        let count = workspace.placements.count
        return "\(count) card\(count == 1 ? "" : "s")"
    }
}
