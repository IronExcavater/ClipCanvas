import SwiftUI
import SwiftData

struct WorkspacesPage: View {
    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @Environment(\.modelContext) private var context

    @State private var search = ""
    @State private var renamingID: UUID?
    @State private var editingName = ""

    private var filteredWorkspaces: [Workspace] {
        guard !search.isEmpty else { return workspaces }
        return workspaces.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            AppSearchField(text: $search, prompt: "Search workspaces")
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(filteredWorkspaces) { ws in
                WorkspaceRowView(
                    workspace: ws,
                    isRenaming: renamingID == ws.id,
                    editingName: $editingName,
                    onActivate: { activateWorkspace(ws) },
                    onRename: { beginRename(ws) },
                    onCommitRename: { commitRename(ws) },
                    onDelete: { softDeleteWorkspace(ws) }
                )
                    .swipeActions(edge: .leading) {
                        Button { beginRename(ws) } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { softDeleteWorkspace(ws) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Workspaces")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createWorkspace) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .accessibilityLabel("New Workspace")
            }
        }
    }

    private func activateWorkspace(_ ws: Workspace) {
        guard renamingID == nil else { return }
        workspaces.forEach { $0.isActive = ($0.id == ws.id) }
    }

    private func createWorkspace() {
        let ws = Workspace(
            name: "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        )
        workspaces.forEach { $0.isActive = false }
        context.insert(ws)
    }

    private func softDeleteWorkspace(_ ws: Workspace) {
        if ws.isActive, let next = workspaces.first(where: { $0.id != ws.id }) {
            next.isActive = true
        }
        ws.softDelete()
    }

    private func beginRename(_ ws: Workspace) {
        editingName = ws.name
        renamingID = ws.id
    }

    private func commitRename(_ ws: Workspace) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { ws.name = trimmed }
        renamingID = nil
    }
}
