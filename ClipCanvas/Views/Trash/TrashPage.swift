import SwiftUI
import SwiftData

struct TrashPage: View {
    @Query(
        filter: #Predicate<Clip> { $0.deletedAt != nil },
        sort: \Clip.deletedAt, order: .reverse
    ) private var deletedClips: [Clip]

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt != nil },
        sort: \Workspace.deletedAt, order: .reverse
    ) private var deletedWorkspaces: [Workspace]

    @Environment(\.modelContext) private var context
    @State private var search = ""
    @State private var isSelecting = false
    @State private var selectedItemIDs = Set<String>()
    @State private var confirmingDeleteAll = false
    @State private var confirmingDeleteSelected = false

    private var filteredWorkspaces: [Workspace] {
        guard !search.isEmpty else { return deletedWorkspaces }
        return deletedWorkspaces.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var filteredClips: [Clip] {
        guard !search.isEmpty else { return deletedClips }
        return deletedClips.filter { $0.content.localizedCaseInsensitiveContains(search) || $0.preview.localizedCaseInsensitiveContains(search) }
    }

    private var hasDeletedItems: Bool {
        !deletedClips.isEmpty || !deletedWorkspaces.isEmpty
    }
    private var selectedClips: [Clip] { deletedClips.filter { selectedItemIDs.contains(key(for: $0)) } }
    private var selectedWorkspaces: [Workspace] { deletedWorkspaces.filter { selectedItemIDs.contains(key(for: $0)) } }

    var body: some View {
        List {
            if hasDeletedItems {
                trashControls
                    .appListItemRowInsets(vertical: 1)
            }

            if deletedWorkspaces.isEmpty && deletedClips.isEmpty {
                ContentUnavailableView(
                    "Recently Deleted is Empty",
                    systemImage: "trash",
                    description: Text("Deleted items appear here before being permanently removed.")
                )
                .appEmptyStateRow()
            } else if filteredWorkspaces.isEmpty && filteredClips.isEmpty {
                ContentUnavailableView.search(text: search)
                    .appEmptyStateRow()
            }

            if !filteredWorkspaces.isEmpty {
                Section("Workspaces") {
                    ForEach(filteredWorkspaces) { ws in
                        DeletedItemRow(
                            title: ws.name,
                            deletedAt: ws.deletedAt,
                            tint: .secondary,
                            isSelecting: isSelecting,
                            isSelected: selectedItemIDs.contains(key(for: ws)),
                            onTap: { toggleSelection(ws) },
                            onRestore: { ws.restore() },
                            onDeleteForever: { context.delete(ws) }
                        )
                        .appListItemRowInsets(vertical: 4)
                    }
                }
            }

            if !filteredClips.isEmpty {
                Section("Clips") {
                    ForEach(filteredClips) { clip in
                        DeletedItemRow(
                            title: clip.preview,
                            deletedAt: clip.deletedAt,
                            tint: clip.primaryDisplayColor,
                            tagTitle: clip.primaryDisplayTagName,
                            isSelecting: isSelecting,
                            isSelected: selectedItemIDs.contains(key(for: clip)),
                            onTap: { toggleSelection(clip) },
                            onRestore: { clip.restore() },
                            onDeleteForever: { context.delete(clip) }
                        )
                        .appListItemRowInsets(vertical: 4)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search deleted")
        .alert("Delete all recently deleted items forever?", isPresented: $confirmingDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive, action: emptyTrash)
        } message: {
            Text("This permanently deletes all recently deleted clips and workspaces.")
        }
        .alert("Delete selected items forever?", isPresented: $confirmingDeleteSelected) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Selected", role: .destructive, action: deleteSelectedForever)
        } message: {
            Text("This permanently deletes the selected recently deleted items.")
        }
    }

    private var trashControls: some View {
        HStack(spacing: 10) {
            Button {
                isSelecting ? endSelection() : beginSelection()
            } label: {
                Label(isSelecting ? "Done" : "Select", systemImage: isSelecting ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelecting ? Color.accentColor : .primary)
            }
            .buttonStyle(.plain)

            if isSelecting {
                Text("\(selectedItemIDs.count) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelecting {
                Button(action: restoreSelected) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .disabled(selectedItemIDs.isEmpty)

                Button(role: .destructive) {
                    confirmingDeleteSelected = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .disabled(selectedItemIDs.isEmpty)
            } else {
                Menu {
                    Button("Restore All", systemImage: "arrow.counterclockwise", action: restoreAll)
                    Button("Delete All Forever", systemImage: "trash", role: .destructive) {
                        confirmingDeleteAll = true
                    }
                } label: {
                    Image(systemName: AppSymbol.options)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(BlendedIconButtonStyle())
            }
        }
        .appListItemContentPadding(horizontal: 10, vertical: 7)
        .appListCard(tint: .secondary, opacity: 0.07)
        .animation(.easeInOut(duration: 0.18), value: isSelecting)
        .animation(.easeInOut(duration: 0.18), value: selectedItemIDs.count)
    }

    // MARK: - Actions

    private func beginSelection() {
        selectedItemIDs.removeAll()
        isSelecting = true
    }

    private func restoreAll() {
        deletedClips.forEach { $0.restore() }
        deletedWorkspaces.forEach { $0.restore() }
    }

    private func restoreSelected() {
        selectedClips.forEach { $0.restore() }
        selectedWorkspaces.forEach { $0.restore() }
        endSelection()
    }

    private func emptyTrash() {
        deletedClips.forEach { context.delete($0) }
        deletedWorkspaces.forEach { context.delete($0) }
    }

    private func deleteSelectedForever() {
        selectedClips.forEach { context.delete($0) }
        selectedWorkspaces.forEach { context.delete($0) }
        endSelection()
    }

    private func toggleSelection(_ clip: Clip) {
        toggle(key(for: clip))
    }

    private func toggleSelection(_ workspace: Workspace) {
        toggle(key(for: workspace))
    }

    private func toggle(_ key: String) {
        if selectedItemIDs.contains(key) {
            selectedItemIDs.remove(key)
        } else {
            selectedItemIDs.insert(key)
        }
    }

    private func endSelection() {
        selectedItemIDs.removeAll()
        isSelecting = false
    }

    private func key(for clip: Clip) -> String { "clip:\(clip.id.uuidString)" }
    private func key(for workspace: Workspace) -> String { "workspace:\(workspace.id.uuidString)" }

}

private struct DeletedItemRow: View {
    let title: String
    let deletedAt: Date?
    let tint: Color
    var tagTitle: String? = nil
    var isSelecting = false
    var isSelected = false
    let onTap: () -> Void
    let onRestore: () -> Void
    let onDeleteForever: () -> Void

    var body: some View {
        Button {
            if isSelecting { onTap() }
        } label: {
            HStack(spacing: 10) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let deletedAt {
                    RelativeAgeText(date: deletedAt, prefix: "Deleted ", emptyText: "Deleted just now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Deleted recently")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let tagTitle {
                AppTagPill(title: tagTitle, color: tint, icon: "tag", isSelected: false)
                }
            }
            .appListItemContentPadding()
        }
        .buttonStyle(.plain)
        .appListCard(tint: tint, opacity: 0.10)
        .swipeActions(edge: .leading) {
            Button(action: onRestore) {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDeleteForever) {
                Label("Delete Forever", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Restore", systemImage: "arrow.counterclockwise", action: onRestore)
            Divider()
            Button("Delete Forever", systemImage: "trash", role: .destructive, action: onDeleteForever)
        }
    }
}
