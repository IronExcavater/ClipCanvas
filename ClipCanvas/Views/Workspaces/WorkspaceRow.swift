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
        ItemRow(tint: tint, opacity: workspace.isActive ? 0.045 : 0.02, isSelecting: isSelecting, isSelected: isSelected) {
            if isRenaming {
                renameField
            } else {
                AppListRowHeader(
                    systemImage: workspace.isCollaborative ? "person.2.fill" : "folder.fill",
                    color: tint,
                    title: workspace.name,
                    subtitle: workspaceSummary,
                    metadata: [AppListRowMetadata("rectangle.stack", value: cardCountText)],
                    date: workspace.updatedAt,
                    dateSuffix: " ago"
                )
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
    private var renameField: some View {
        HStack(spacing: 12) {
            AppIconBadge(systemImage: workspace.name.isEmpty ? "plus" : "folder.fill", size: 34, iconSize: 16, color: tint)
            VStack(alignment: .leading, spacing: 4) {
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
                Text(workspace.name.isEmpty ? "New workspace" : workspaceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workspaceSummary: String {
        if workspace.isCollaborative {
            return "Owner: \(workspace.ownerName ?? workspace.sharedByName ?? "Unknown")"
        }
        let chats = workspace.chats.count
        return "\(chats) \(chats == 1 ? "chat" : "chats")"
    }

    private var cardCountText: String {
        let count = workspace.canvasObjects.filter(\.isCanvasContent).count
        return "\(count)"
    }
}
