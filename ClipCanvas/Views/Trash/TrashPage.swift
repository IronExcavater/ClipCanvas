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

    var body: some View {
        List {
            if deletedWorkspaces.isEmpty && deletedClips.isEmpty {
                ContentUnavailableView(
                    "Recently Deleted is Empty",
                    systemImage: "trash",
                    description: Text("Deleted items appear here before being permanently removed.")
                )
                .listRowBackground(Color.clear)
            }

            if !deletedWorkspaces.isEmpty {
                Section("Workspaces") {
                    ForEach(deletedWorkspaces) { ws in
                        workspaceRow(ws)
                    }
                }
            }

            if !deletedClips.isEmpty {
                Section("Clips") {
                    ForEach(deletedClips) { clip in
                        clipRow(clip)
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !deletedClips.isEmpty || !deletedWorkspaces.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Empty All", role: .destructive, action: emptyTrash)
                }
            }
        }
    }

    // MARK: - Workspace row

    private func workspaceRow(_ ws: Workspace) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ws.name)
                    .font(.subheadline.weight(.medium))
                if let deletedAt = ws.deletedAt {
                    Text("Deleted \(deletedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Restore") { ws.restore() }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
        }
        .swipeActions(edge: .leading) {
            Button { ws.restore() } label: {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { context.delete(ws) } label: {
                Label("Delete Forever", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Restore", systemImage: "arrow.counterclockwise") { ws.restore() }
            Divider()
            Button("Delete Forever", systemImage: "trash", role: .destructive) { context.delete(ws) }
        }
    }

    // MARK: - Clip row

    private func clipRow(_ clip: Clip) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.color.background)
                .frame(width: 6, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.preview)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let deletedAt = clip.deletedAt {
                    Text("Deleted \(deletedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Restore") { clip.restore() }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
        }
        .swipeActions(edge: .leading) {
            Button { clip.restore() } label: {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { context.delete(clip) } label: {
                Label("Delete Forever", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Restore", systemImage: "arrow.counterclockwise") { clip.restore() }
            Divider()
            Button("Delete Forever", systemImage: "trash", role: .destructive) { context.delete(clip) }
        }
    }

    // MARK: - Actions

    private func emptyTrash() {
        deletedClips.forEach { context.delete($0) }
        deletedWorkspaces.forEach { context.delete($0) }
    }
}
