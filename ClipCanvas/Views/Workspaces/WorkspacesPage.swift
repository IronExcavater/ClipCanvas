import SwiftUI
import SwiftData

struct WorkspacesPage: View {
    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }, sort: \Workspace.sortIndex) private var workspaces: [Workspace]

    @Environment(\.modelContext) private var context
    @State private var search = ""
    @State private var renamingID: UUID?
    @State private var editingName = ""
    @State private var selection = SelectionState<UUID>()

    private var filtered: [Workspace] {
        search.isEmpty ? workspaces
                       : workspaces.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            AppSearchSelectionBar(
                search: $search.withListAnimation,
                prompt: "Search workspaces",
                isSelecting: selection.isActive,
                selectedCount: selection.count,
                onBeginSelection: { renamingID = nil; selection.begin() },
                onEndSelection: { selection.end() }
            ) {
                Button(role: .destructive, action: deleteSelected) {
                    AppToolbarCircleLabel(systemImage: "trash", size: 40, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selection.isEmpty)
            }
            .appListItemRowInsets(vertical: 4)

            if filtered.isEmpty {
                AppListEmptyState(
                    isSourceEmpty: workspaces.isEmpty,
                    searchText: search,
                    title: "No Workspaces",
                    systemImage: "rectangle.3.group",
                    description: "No saved workspaces."
                )
            }

            ForEach(filtered) { ws in
                WorkspaceRow(
                    workspace: ws,
                    isRenaming: renamingID == ws.id,
                    editingName: $editingName,
                    isSelecting: selection.isActive,
                    isSelected: selection.contains(ws.id),
                    onActivate: { selection.isActive ? selection.toggle(ws.id) : activateWorkspace(ws) },
                    onRename: { beginRename(ws) },
                    onCommitRename: { commitRename(ws) },
                    onDelete: { WorkspaceActionService.softDelete(ws, among: workspaces) }
                )
                .appListItemRowInsets(vertical: 3)
                .swipeActions(edge: .leading) {
                    AppSwipeIconButton(systemImage: "pencil", tint: .blue, accessibilityLabel: "Rename") {
                        beginRename(ws)
                    }
                }
                .swipeActions(edge: .trailing) {
                    AppSwipeIconButton(systemImage: "trash", role: .destructive, accessibilityLabel: "Delete") {
                        WorkspaceActionService.softDelete(ws, among: workspaces)
                    }
                }
            }
        }
        .appPageListStyle()
        .navigationTitle("Workspaces")
        .animation(.easeInOut(duration: 0.18), value: search.isEmpty)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: createWorkspace) { AppCircleIconLabel(systemImage: "plus") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New Workspace")
            }
        }
    }

    private func activateWorkspace(_ ws: Workspace) {
        guard renamingID == nil else { return }
        WorkspaceActionService.activate(ws, among: workspaces)
    }

    private func createWorkspace() {
        search = ""
        selection.end()
        let ws = WorkspaceActionService.create(in: context, existing: workspaces, name: "")
        editingName = ""
        renamingID = ws.id
    }

    private func beginRename(_ ws: Workspace) {
        editingName = WorkspaceNamePolicy.limitedEditingText(ws.name)
        renamingID = ws.id
    }

    private func commitRename(_ ws: Workspace) {
        WorkspaceActionService.rename(ws, to: editingName)
        renamingID = nil
    }

    private func deleteSelected() {
        workspaces.filter { selection.contains($0.id) }
                  .forEach { WorkspaceActionService.softDelete($0, among: workspaces) }
        selection.end()
    }
}
