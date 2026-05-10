import SwiftData
import SwiftUI

struct WorkspacesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Workspace> { !$0.isArchived },
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]

    @State private var newWorkspaceName = ""
    @State private var renameWorkspace: Workspace?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New workspace", text: $newWorkspaceName)
                            .textInputAutocapitalization(.words)
                        Button(action: createWorkspace) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Workspaces") {
                    ForEach(workspaces) { workspace in
                        WorkspaceManagementRow(
                            workspace: workspace,
                            activate: { activate(workspace) },
                            rename: {
                                renameWorkspace = workspace
                                renameText = workspace.name
                            },
                            archive: { archive(workspace) }
                        )
                    }
                    .onMove(perform: move)
                }
            }
            .navigationTitle("Workspaces")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .alert("Rename Workspace", isPresented: Binding(
                get: { renameWorkspace != nil },
                set: { if !$0 { renameWorkspace = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Rename", action: applyRename)
                Button("Cancel", role: .cancel) { renameWorkspace = nil }
            }
        }
    }

    private func createWorkspace() {
        let trimmed = newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let workspace = Workspace(name: trimmed, sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1, isActive: true)
        modelContext.insert(workspace)
        newWorkspaceName = ""
        activate(workspace)
    }

    private func activate(_ workspace: Workspace) {
        for item in workspaces {
            item.isActive = item.id == workspace.id
            item.updatedAt = Date()
        }
        workspace.isActive = true
        workspace.isArchived = false
        workspace.updatedAt = Date()
        router.pendingRoute = .workspace(workspace.id)
        dismiss()
    }

    private func archive(_ workspace: Workspace) {
        workspace.isArchived = true
        workspace.isActive = false
        workspace.updatedAt = Date()
        if workspaces.filter({ !$0.isArchived && $0.id != workspace.id }).isEmpty {
            let workspace = Workspace(name: "Canvas", sortIndex: 0, isActive: true)
            modelContext.insert(workspace)
        } else {
            AppBootstrap.ensureActiveWorkspace(in: modelContext)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = workspaces
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, workspace) in reordered.enumerated() {
            workspace.sortIndex = index
            workspace.updatedAt = Date()
        }
    }

    private func applyRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let workspace = renameWorkspace, !trimmed.isEmpty else { return }
        workspace.name = trimmed
        workspace.updatedAt = Date()
        renameWorkspace = nil
    }
}

private struct WorkspaceManagementRow: View {
    let workspace: Workspace
    let activate: () -> Void
    let rename: () -> Void
    let archive: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workspace.isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(workspace.isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(workspace.name)
                    .font(.headline)
                Text("\(workspace.cards.count) card\(workspace.cards.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Make Active", systemImage: "checkmark.circle", action: activate)
                Button("Rename", systemImage: "pencil", action: rename)
                Button("Archive", systemImage: "archivebox", role: .destructive, action: archive)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: activate)
    }
}
