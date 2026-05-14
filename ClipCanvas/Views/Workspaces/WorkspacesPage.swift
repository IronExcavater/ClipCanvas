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
    @State private var isSelecting = false
    @State private var selectedWorkspaceIDs = Set<UUID>()

    private var filteredWorkspaces: [Workspace] {
        guard !search.isEmpty else { return workspaces }
        return workspaces.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
    private var selectedWorkspaces: [Workspace] {
        workspaces.filter { selectedWorkspaceIDs.contains($0.id) }
    }

    var body: some View {
        let searchBinding = Binding(
            get: { search },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.18)) {
                    search = newValue
                }
            }
        )
        List {
            AppSearchSelectionBar(
                search: searchBinding,
                prompt: "Search workspaces",
                isSelecting: isSelecting,
                selectedCount: selectedWorkspaceIDs.count,
                onBeginSelection: beginSelection,
                onEndSelection: endSelection
            ) {
                Button(role: .destructive, action: deleteSelected) {
                    AppToolbarCircleLabel(systemImage: "trash", size: 40, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selectedWorkspaceIDs.isEmpty)
            }
            .appListItemRowInsets(horizontal: 14, vertical: 4)

            if filteredWorkspaces.isEmpty {
                if workspaces.isEmpty {
                    ContentUnavailableView(
                        "No Workspaces",
                        systemImage: "rectangle.3.group",
                        description: Text("Create a workspace to get started.")
                    )
                    .appEmptyStateRow()
                } else {
                    ContentUnavailableView.search(text: search)
                        .appEmptyStateRow()
                }
            }

            ForEach(filteredWorkspaces) { ws in
                WorkspaceRowView(
                    workspace: ws,
                    isRenaming: renamingID == ws.id,
                    editingName: $editingName,
                    isSelecting: isSelecting,
                    isSelected: selectedWorkspaceIDs.contains(ws.id),
                    onActivate: { isSelecting ? toggleSelection(ws) : activateWorkspace(ws) },
                    onRename: { beginRename(ws) },
                    onCommitRename: { commitRename(ws) },
                    onDelete: { WorkspaceActionService.softDelete(ws, among: workspaces) }
                )
                    .appListItemRowInsets(vertical: 3)
                    .swipeActions(edge: .leading) {
                        Button { beginRename(ws) } label: {
                            Image(systemName: "pencil")
                        }
                        .tint(.blue)
                        .accessibilityLabel("Rename")
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { WorkspaceActionService.softDelete(ws, among: workspaces) } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete")
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Workspaces")
        .animation(.easeInOut(duration: 0.18), value: search.isEmpty)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarActions
            }
        }
    }

    @ViewBuilder
    private var toolbarActions: some View {
        AppToolbarCircleButton(systemImage: "plus", action: createWorkspace)
            .accessibilityLabel("New Workspace")
            .opacity(isSelecting ? 0 : 1)
            .disabled(isSelecting)
    }

    private func activateWorkspace(_ ws: Workspace) {
        guard renamingID == nil else { return }
        WorkspaceActionService.activate(ws, among: workspaces)
    }

    private func createWorkspace() {
        search = ""
        endSelection()
        let workspace = WorkspaceActionService.create(in: context, existing: workspaces, name: "")
        editingName = ""
        renamingID = workspace.id
    }

    private func beginRename(_ ws: Workspace) {
        editingName = WorkspaceNamePolicy.limitedEditingText(ws.name)
        renamingID = ws.id
    }

    private func commitRename(_ ws: Workspace) {
        WorkspaceActionService.rename(ws, to: editingName)
        renamingID = nil
    }

    private func toggleSelection(_ ws: Workspace) {
        if selectedWorkspaceIDs.contains(ws.id) {
            selectedWorkspaceIDs.remove(ws.id)
        } else {
            selectedWorkspaceIDs.insert(ws.id)
        }
    }

    private func beginSelection() {
        renamingID = nil
        selectedWorkspaceIDs.removeAll()
        isSelecting = true
    }

    private func deleteSelected() {
        selectedWorkspaces.forEach { WorkspaceActionService.softDelete($0, among: workspaces) }
        endSelection()
    }

    private func endSelection() {
        selectedWorkspaceIDs.removeAll()
        isSelecting = false
    }
}
