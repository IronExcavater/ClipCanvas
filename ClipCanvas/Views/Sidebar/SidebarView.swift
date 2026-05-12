import SwiftUI
import SwiftData

struct SidebarView: View {
    let workspaces: [Workspace]
    let activeWorkspace: Workspace?
    let onActivateWorkspace: (Workspace) -> Void
    let onCreateWorkspace: () -> Void
    let onPlaceClip: (Clip) -> Void

    @Query(sort: \Clip.createdAt, order: .reverse)
    private var clips: [Clip]

    @State private var search = ""
    @Environment(\.modelContext) private var context

    private var filtered: [Clip] {
        guard !search.isEmpty else { return clips }
        return clips.filter { $0.content.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(label: String, clips: [Clip])] {
        let calendar = Calendar.current
        var today: [Clip] = [], yesterday: [Clip] = [], week: [Clip] = [], older: [Clip] = []
        let now = Date()
        for clip in filtered {
            if calendar.isDateInToday(clip.createdAt) { today.append(clip) }
            else if calendar.isDateInYesterday(clip.createdAt) { yesterday.append(clip) }
            else if let ago = calendar.date(byAdding: .day, value: -7, to: now), clip.createdAt > ago { week.append(clip) }
            else { older.append(clip) }
        }
        return [("Today", today), ("Yesterday", yesterday), ("This Week", week), ("Older", older)]
            .filter { !$0.clips.isEmpty }
    }

    var body: some View {
        List {
            workspacePicker
            clipList
        }
        .listStyle(.sidebar)
        .searchable(text: $search, prompt: "Search clips…")
        .navigationTitle("Clips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreateWorkspace) {
                    Label("New Workspace", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Workspace picker

    @ViewBuilder
    private var workspacePicker: some View {
        Section("Workspaces") {
            ForEach(workspaces) { ws in
                Button {
                    onActivateWorkspace(ws)
                } label: {
                    HStack {
                        Image(systemName: ws.isActive ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(ws.isActive ? .accentColor : .secondary)
                        Text(ws.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(ws.placements.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Clip list

    @ViewBuilder
    private var clipList: some View {
        if filtered.isEmpty {
            if clips.isEmpty {
                ContentUnavailableView(
                    "No clips yet",
                    systemImage: "doc.on.clipboard",
                    description: Text("Paste content to add your first clip.")
                )
                .listRowBackground(Color.clear)
            } else {
                ContentUnavailableView.search(text: search)
                    .listRowBackground(Color.clear)
            }
        } else {
            ForEach(grouped, id: \.label) { group in
                Section(group.label) {
                    ForEach(group.clips) { clip in
                        SidebarClipRow(
                            clip: clip,
                            onPlace: { onPlaceClip(clip) }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.delete(clip) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sidebar clip row

private struct SidebarClipRow: View {
    let clip: Clip
    let onPlace: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.color.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(clip.color.background.opacity(0.5), lineWidth: 0.5)
                )
                .frame(width: 8, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.preview)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: clip.type.icon)
                        .font(.caption2)
                    Text(clip.createdAt, style: .relative)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onPlace) {
                Image(systemName: "arrow.right.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Place on canvas")
        }
        .padding(.vertical, 2)
    }
}
