import SwiftUI
import SwiftData

struct TrashPage: View {
    @Query(filter: #Predicate<Clip>      { $0.deletedAt != nil }, sort: \Clip.deletedAt,      order: .reverse) private var deletedClips: [Clip]
    @Query(filter: #Predicate<Workspace> { $0.deletedAt != nil }, sort: \Workspace.deletedAt, order: .reverse) private var deletedWorkspaces: [Workspace]
    @Query(filter: #Predicate<AIChat>    { $0.deletedAt != nil }, sort: \AIChat.deletedAt,    order: .reverse) private var deletedChats: [AIChat]
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
    private var filteredChats: [AIChat] {
        search.isEmpty ? deletedChats
                       : deletedChats.filter { $0.title.localizedCaseInsensitiveContains(search)
                                              || $0.preview.localizedCaseInsensitiveContains(search) }
    }
    private var hasDeletedItems: Bool { !deletedClips.isEmpty || !deletedWorkspaces.isEmpty || !deletedChats.isEmpty }
    private var activeWorkspace: Workspace? { liveWorkspaces.first(where: \.isActive) ?? liveWorkspaces.first }
    private var selectedClips: [Clip]      { deletedClips.filter      { selection.contains(key(for: $0)) } }
    private var selectedWorkspaces: [Workspace] { deletedWorkspaces.filter { selection.contains(key(for: $0)) } }
    private var selectedChats: [AIChat] { deletedChats.filter { selection.contains(key(for: $0)) } }

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
            .appListItemRowInsets(vertical: 4)

            if !hasDeletedItems || (filteredWorkspaces.isEmpty && filteredClips.isEmpty && filteredChats.isEmpty) {
                AppListEmptyState(
                    isSourceEmpty: !hasDeletedItems,
                    searchText: search,
                    title: "Recently Deleted is Empty",
                    systemImage: "trash",
                    description: "No recoverable items."
                )
            }

            if !filteredWorkspaces.isEmpty {
                Section("Workspaces") {
                    ForEach(filteredWorkspaces) { ws in
                        TrashItemRow(title: ws.name, systemImage: "folder", deletedAt: ws.deletedAt,
                                     tint: .secondary, isSelecting: selection.isActive,
                                     isSelected: selection.contains(key(for: ws)),
                                     onTap: { selection.toggle(key(for: ws)) },
                                     onRestore: { ws.restore() },
                                     onDeleteForever: { TrashRetentionService.deleteForever(ws, in: context) })
                        .appListItemRowInsets(vertical: 3)
                    }
                }
            }

            if !filteredChats.isEmpty {
                Section("AI Chats") {
                    ForEach(filteredChats) { chat in
                        TrashItemRow(
                            title: chat.title,
                            systemImage: "sparkles",
                            deletedAt: chat.deletedAt,
                            tint: .accentColor,
                            isSelecting: selection.isActive,
                            isSelected: selection.contains(key(for: chat)),
                            onTap: { selection.toggle(key(for: chat)) },
                            onRestore: { chat.restore() },
                            onDeleteForever: { context.delete(chat) }
                        )
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
        .overlay {
            if confirmingDeleteAll {
                AppConfirmationOverlay(
                    title: "Delete everything forever?",
                    message: "This permanently deletes all recently deleted items.",
                    destructiveTitle: "Delete All",
                    onConfirm: {
                        emptyTrash()
                        confirmingDeleteAll = false
                    },
                    onCancel: { confirmingDeleteAll = false }
                )
            } else if confirmingDeleteSelected {
                AppConfirmationOverlay(
                    title: "Delete selected items forever?",
                    message: "This permanently deletes the selected recently deleted items.",
                    destructiveTitle: "Delete",
                    onConfirm: {
                        deleteSelectedForever()
                        confirmingDeleteSelected = false
                    },
                    onCancel: { confirmingDeleteSelected = false }
                )
            }
        }
    }

    // MARK: - Actions

    private func restoreAll() {
        deletedClips.forEach { $0.restore() }
        deletedWorkspaces.forEach { $0.restore() }
        deletedChats.forEach { $0.restore() }
    }

    private func restoreSelected() {
        selectedClips.forEach { $0.restore() }
        selectedWorkspaces.forEach { $0.restore() }
        selectedChats.forEach { $0.restore() }
        selection.end()
    }

    private func emptyTrash() {
        deletedClips.forEach { context.delete($0) }
        deletedWorkspaces.forEach { TrashRetentionService.deleteForever($0, in: context) }
        deletedChats.forEach { context.delete($0) }
    }

    private func deleteSelectedForever() {
        selectedClips.forEach { context.delete($0) }
        selectedWorkspaces.forEach { TrashRetentionService.deleteForever($0, in: context) }
        selectedChats.forEach { context.delete($0) }
        selection.end()
    }

    private func addToCanvas(_ clip: Clip) {
        guard let activeWorkspace else { return }
        clip.restore()
        activeWorkspace.place(clip: clip)
    }

    private func key(for clip: Clip) -> String      { "clip:\(clip.id.uuidString)" }
    private func key(for ws: Workspace) -> String   { "ws:\(ws.id.uuidString)" }
    private func key(for chat: AIChat) -> String    { "chat:\(chat.id.uuidString)" }
}
