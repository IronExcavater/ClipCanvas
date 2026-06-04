import SwiftUI

struct WorkspaceRow: View {
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

    private var tint: Color { workspace.isActive ? Color.accentColor : Color.secondary }

    var body: some View {
        ItemRow(tint: tint, opacity: workspace.isActive ? 0.10 : 0.06, isSelecting: isSelecting, isSelected: isSelected) {
            HStack(alignment: .center, spacing: 8) {
                // Custom icon: checkmark for active, folder for inactive
                Image(systemName: workspace.isActive ? "checkmark" : "folder.fill")
                    .font(.system(size: workspace.isActive ? 12 : 14, weight: .bold))
                    .foregroundStyle(workspace.isActive ? .white : .primary.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(workspace.isActive ? Color.accentColor : Color.primary.opacity(0.10), in: Circle())

                nameContent

                Spacer(minLength: 8)

                RelativeAgeText(date: workspace.updatedAt, suffix: " ago")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.58))
            }

            if workspace.isActive {
                Label("Active workspace", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .onTapGesture(perform: onActivate)
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: onRename)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .onChange(of: isRenaming) { _, newValue in if newValue { focused = true } }
        .animation(.easeInOut(duration: 0.18), value: workspace.isActive)
    }

    @ViewBuilder
    private var nameContent: some View {
        if isRenaming {
            TextField("Workspace name", text: $editingName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .submitLabel(.done)
                .focused($focused)
                .onChange(of: editingName) { _, newValue in
                    let limited = WorkspaceNamePolicy.limitedEditingText(newValue)
                    if limited != newValue { editingName = limited }
                }
                .onSubmit(onCommitRename)
                .onDisappear(perform: onCommitRename)
        } else {
            Text(workspace.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}
