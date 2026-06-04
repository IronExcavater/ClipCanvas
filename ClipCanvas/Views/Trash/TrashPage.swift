import SwiftUI
import SwiftData

struct TrashPage: View {
    @Query(filter: #Predicate<Clip>      { $0.deletedAt != nil }, sort: \Clip.deletedAt,      order: .reverse) private var deletedClips: [Clip]
    @Query(filter: #Predicate<Workspace> { $0.deletedAt != nil }, sort: \Workspace.deletedAt, order: .reverse) private var deletedWorkspaces: [Workspace]
    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }, sort: \Workspace.sortIndex)                  private var liveWorkspaces: [Workspace]

    @Environment(\.modelContext) private var context
    @State private var search = ""
    @State private var selection = SelectionState<String>()
    @State private var confirmingDeleteAll = false
    @State private var confirmingDeleteSelected = false

    private var filteredWorkspaces: [Workspace] {
        search.isEmpty ? deletedWorkspaces
                       : deletedWorkspaces.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
    private var filteredClips: [Clip] {
        search.isEmpty ? deletedClips
                       : deletedClips.filter { $0.content.localizedCaseInsensitiveContains(search)
                                              || $0.preview.localizedCaseInsensitiveContains(search) }
    }
    private var hasDeletedItems: Bool { !deletedClips.isEmpty || !deletedWorkspaces.isEmpty }
    private var activeWorkspace: Workspace? { liveWorkspaces.first(where: \.isActive) ?? liveWorkspaces.first }
    private var selectedClips: [Clip]      { deletedClips.filter      { selection.contains(key(for: $0)) } }
    private var selectedWorkspaces: [Workspace] { deletedWorkspaces.filter { selection.contains(key(for: $0)) } }

    var body: some View {
        List {
            AppSearchSelectionBar(
                search: $search.withListAnimation,
                prompt: "Search deleted",
                isSelecting: selection.isActive,
                selectedCount: selection.count,
                onBeginSelection: { selection.begin() },
                onEndSelection: { selection.end() }
            ) {
                Button(action: restoreSelected) {
                    AppToolbarCircleLabel(systemImage: "arrow.counterclockwise", size: 40, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selection.isEmpty)

                Button(role: .destructive) { confirmingDeleteSelected = true } label: {
                    AppToolbarCircleLabel(systemImage: "trash", size: 40, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selection.isEmpty)
            }
            .appListItemRowInsets(horizontal: 14, vertical: 4)

            if deletedWorkspaces.isEmpty && deletedClips.isEmpty {
                ContentUnavailableView("Recently Deleted is Empty", systemImage: "trash",
                    description: Text("Deleted items appear here before being permanently removed."))
                .appEmptyStateRow()
            } else if filteredWorkspaces.isEmpty && filteredClips.isEmpty {
                ContentUnavailableView.search(text: search).appEmptyStateRow()
            }

            if !filteredWorkspaces.isEmpty {
                Section("Workspaces") {
                    ForEach(filteredWorkspaces) { ws in
                        TrashItemRow(title: ws.name, systemImage: "folder", deletedAt: ws.deletedAt,
                                     tint: .secondary, isSelecting: selection.isActive,
                                     isSelected: selection.contains(key(for: ws)),
                                     onTap: { selection.toggle(key(for: ws)) },
                                     onRestore: { ws.restore() },
                                     onDeleteForever: { context.delete(ws) })
                        .appListItemRowInsets(vertical: 3)
                    }
                }
            }

            if !filteredClips.isEmpty {
                Section("Clips") {
                    ForEach(filteredClips) { clip in
                        TrashItemRow(title: clip.preview, systemImage: clip.type.icon,
                                     deletedAt: clip.deletedAt, tint: clip.primaryDisplayColor,
                                     tags: Array(clip.tags.sorted { $0.sortIndex < $1.sortIndex }.prefix(2)),
                                     dragID: clip.id.uuidString,
                                     isSelecting: selection.isActive,
                                     isSelected: selection.contains(key(for: clip)),
                                     onTap: { selection.toggle(key(for: clip)) },
                                     onRestore: { clip.restore() },
                                     onDeleteForever: { context.delete(clip) },
                                     onAddToCanvas: { addToCanvas(clip) })
                        .appListItemRowInsets(vertical: 3)
                    }
                }
            }
        }
        .appPageListStyle()
        .navigationTitle("Recently Deleted")
        .animation(.easeInOut(duration: 0.18), value: search.isEmpty)
        .toolbar {
            if hasDeletedItems {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Restore All", systemImage: "arrow.counterclockwise", action: restoreAll)
                        Button("Delete All", systemImage: "trash", role: .destructive) { confirmingDeleteAll = true }
                    } label: { AppCircleIconLabel(systemImage: AppSymbol.options) }
                    .accessibilityLabel("Recently deleted options")
                    .opacity(selection.isActive ? 0 : 1)
                    .disabled(selection.isActive)
                }
            }
        }
        .task { TrashRetentionService.purgeExpired(in: context) }
        .alert("Delete all recently deleted items forever?", isPresented: $confirmingDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive, action: emptyTrash)
        } message: { Text("This permanently deletes all recently deleted clips and workspaces.") }
        .alert("Delete selected items forever?", isPresented: $confirmingDeleteSelected) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Selected", role: .destructive, action: deleteSelectedForever)
        } message: { Text("This permanently deletes the selected recently deleted items.") }
    }

    // MARK: - Actions

    private func restoreAll() {
        deletedClips.forEach { $0.restore() }
        deletedWorkspaces.forEach { $0.restore() }
    }

    private func restoreSelected() {
        selectedClips.forEach { $0.restore() }
        selectedWorkspaces.forEach { $0.restore() }
        selection.end()
    }

    private func emptyTrash() {
        deletedClips.forEach { context.delete($0) }
        deletedWorkspaces.forEach { context.delete($0) }
    }

    private func deleteSelectedForever() {
        selectedClips.forEach { context.delete($0) }
        selectedWorkspaces.forEach { context.delete($0) }
        selection.end()
    }

    private func addToCanvas(_ clip: Clip) {
        guard let activeWorkspace else { return }
        clip.restore()
        activeWorkspace.place(clip: clip)
    }

    private func key(for clip: Clip) -> String      { "clip:\(clip.id.uuidString)" }
    private func key(for ws: Workspace) -> String   { "ws:\(ws.id.uuidString)" }
}
