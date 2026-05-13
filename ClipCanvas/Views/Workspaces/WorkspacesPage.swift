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
    @State private var searchPresented = false

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
            } else {
                selectionControl
                    .appListItemRowInsets(vertical: 0)
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
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { WorkspaceActionService.softDelete(ws, among: workspaces) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Workspaces")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: searchBinding, isPresented: $searchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search workspaces")
        .animation(.easeInOut(duration: 0.18), value: search.isEmpty)
        .animation(.easeInOut(duration: 0.18), value: searchPresented)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !isSelecting {
                    Button(action: createWorkspace) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(BlendedIconButtonStyle())
                    .accessibilityLabel("New Workspace")
                    .opacity(searchPresented ? 0 : 1)
                    .disabled(searchPresented)
                }
            }
        }
    }

    private var selectionControl: some View {
        AppListSelectionControl(
            isSelecting: isSelecting,
            selectedCount: selectedWorkspaceIDs.count,
            selectTitle: "Select",
            onToggle: { isSelecting ? endSelection() : beginSelection() }
        ) {
            Button(role: .destructive, action: deleteSelected) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .appSelectionIconButtonStyle()
            .disabled(selectedWorkspaceIDs.isEmpty)
        }
    }

    private func activateWorkspace(_ ws: Workspace) {
        guard renamingID == nil else { return }
        WorkspaceActionService.activate(ws, among: workspaces)
    }

    private func createWorkspace() {
        let workspace = WorkspaceActionService.create(in: context, existing: workspaces, name: "")
        editingName = ""
        renamingID = workspace.id
    }

    private func beginRename(_ ws: Workspace) {
        editingName = ws.name
        renamingID = ws.id
    }

    private func commitRename(_ ws: Workspace) {
        let name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        WorkspaceActionService.rename(ws, to: name.isEmpty ? "Untitled" : name)
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
