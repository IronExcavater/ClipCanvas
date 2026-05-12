import SwiftUI
import SwiftData

struct WorkspacesPage: View {
    @Query(sort: \Workspace.sortIndex) private var workspaces: [Workspace]
    @Environment(\.modelContext) private var context

    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var renamingID: UUID?
    @State private var editingName = ""
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        List {
            ForEach(workspaces) { ws in
                workspaceRow(ws)
                    .swipeActions(edge: .leading) {
                        Button {
                            beginRename(ws)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleteWorkspace(ws) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Workspaces")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isSelectMode {
                    Button("Done") { exitSelectMode() }
                        .font(.body.weight(.semibold))
                } else {
                    Button(action: createWorkspace) {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if isSelectMode {
                    Button(role: .destructive, action: deleteSelected) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
        .environment(\.editMode, .constant(isSelectMode ? .active : .inactive))
    }

    // MARK: - Row

    @ViewBuilder
    private func workspaceRow(_ ws: Workspace) -> some View {
        Button(action: { activateWorkspace(ws) }) {
            HStack(spacing: 12) {
                if isSelectMode {
                    Image(systemName: selectedIDs.contains(ws.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(ws.id) ? Color.accentColor : Color.secondary)
                        .font(.system(size: 20))
                        .animation(.spring(response: 0.2), value: selectedIDs.contains(ws.id))
                        .onTapGesture { toggleSelect(ws.id) }
                }

                VStack(alignment: .leading, spacing: 2) {
                    if renamingID == ws.id {
                        TextField("Workspace name", text: $editingName)
                            .font(.subheadline.weight(.medium))
                            .focused($renameFieldFocused)
                            .onSubmit { commitRename(ws) }
                            .onDisappear { if renamingID == ws.id { commitRename(ws) } }
                    } else {
                        Text(ws.name)
                            .font(.subheadline.weight(.medium))
                    }

                    Text("\(ws.placements.count) card\(ws.placements.count == 1 ? "" : "s") · \(ws.updatedAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if ws.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            if !isSelectMode { enterSelectMode(ws.id) }
        }
        .contextMenu {
            Button("Activate", systemImage: "checkmark.circle") { activateWorkspace(ws) }
            Button("Rename", systemImage: "pencil") { beginRename(ws) }
            Button("Select", systemImage: "checkmark.circle") { enterSelectMode(ws.id) }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { deleteWorkspace(ws) }
        }
    }

    // MARK: - Actions

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

    private func deleteWorkspace(_ ws: Workspace) {
        if ws.isActive, let next = workspaces.first(where: { $0.id != ws.id }) {
            next.isActive = true
        }
        context.delete(ws)
    }

    private func beginRename(_ ws: Workspace) {
        editingName = ws.name
        renamingID = ws.id
        renameFieldFocused = true
    }

    private func commitRename(_ ws: Workspace) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { ws.name = trimmed }
        renamingID = nil
        renameFieldFocused = false
    }

    private func enterSelectMode(_ id: UUID) {
        isSelectMode = true
        selectedIDs = [id]
    }

    private func toggleSelect(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private func exitSelectMode() {
        isSelectMode = false
        selectedIDs.removeAll()
    }

    private func deleteSelected() {
        let toDelete = workspaces.filter { selectedIDs.contains($0.id) }
        toDelete.forEach { deleteWorkspace($0) }
        exitSelectMode()
    }
}
