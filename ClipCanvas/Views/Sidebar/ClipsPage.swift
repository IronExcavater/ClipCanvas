import SwiftUI
import SwiftData

struct ClipsPage: View {
    @Query(sort: \Clip.createdAt, order: .reverse) private var allClips: [Clip]
    @Environment(\.modelContext) private var context

    @State private var search = ""
    @State private var filterType: ClipType? = nil
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []

    private var filtered: [Clip] {
        allClips.filter { clip in
            let matchesSearch = search.isEmpty || clip.content.localizedCaseInsensitiveContains(search)
            let matchesType = filterType == nil || clip.type == filterType
            return matchesSearch && matchesType
        }
    }

    private var grouped: [(label: String, clips: [Clip])] {
        let cal = Calendar.current
        let now = Date()
        var today: [Clip] = [], yesterday: [Clip] = [], week: [Clip] = [], older: [Clip] = []
        for c in filtered {
            if cal.isDateInToday(c.createdAt) { today.append(c) }
            else if cal.isDateInYesterday(c.createdAt) { yesterday.append(c) }
            else if let ago = cal.date(byAdding: .day, value: -7, to: now), c.createdAt > ago { week.append(c) }
            else { older.append(c) }
        }
        return [("Today", today), ("Yesterday", yesterday), ("This Week", week), ("Older", older)]
            .filter { !$0.clips.isEmpty }
    }

    var body: some View {
        List {
            if !isSelectMode {
                typeFilterPicker
            }

            if filtered.isEmpty {
                if allClips.isEmpty {
                    ContentUnavailableView("No clips yet", systemImage: "doc.on.clipboard",
                        description: Text("Copy something to get started."))
                        .listRowBackground(Color.clear)
                } else {
                    ContentUnavailableView.search(text: search)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(grouped, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.clips) { clip in
                            clipRow(clip)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        clip.isPinned.toggle()
                                    } label: {
                                        Label(clip.isPinned ? "Unpin" : "Pin",
                                              systemImage: clip.isPinned ? "pin.slash" : "pin")
                                    }
                                    .tint(.orange)
                                }
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
        .searchable(text: $search, prompt: "Search clips…")
        .navigationTitle("All Clips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isSelectMode {
                    Button("Done") { exitSelectMode() }
                        .font(.body.weight(.semibold))
                } else {
                    Menu {
                        Button("Select", systemImage: "checkmark.circle") { isSelectMode = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if isSelectMode {
                    HStack(spacing: 16) {
                        Button(role: .destructive, action: deleteSelected) {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedIDs.isEmpty)
                        Button(action: copySelected) {
                            Image(systemName: "doc.on.doc")
                        }
                        .disabled(selectedIDs.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Filter picker

    private var typeFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", type: nil)
                ForEach(ClipType.allCases, id: \.self) { type in
                    filterChip(label: type.rawValue.capitalized, icon: type.icon, type: type)
                }
            }
            .padding(.horizontal, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func filterChip(label: String, icon: String? = nil, type: ClipType?) -> some View {
        Button {
            filterType = (filterType == type) ? nil : type
        } label: {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.caption) }
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                filterType == type ? Color.accentColor : Color.secondary.opacity(0.12),
                in: Capsule()
            )
            .foregroundStyle(filterType == type ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Clip row

    @ViewBuilder
    private func clipRow(_ clip: Clip) -> some View {
        Button(action: { copyClip(clip) }) {
            HStack(spacing: 12) {
                if isSelectMode {
                    Image(systemName: selectedIDs.contains(clip.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(clip.id) ? Color.accentColor : Color.secondary)
                        .font(.system(size: 20))
                        .animation(.spring(response: 0.2), value: selectedIDs.contains(clip.id))
                        .onTapGesture { toggleSelect(clip.id) }
                }

                RoundedRectangle(cornerRadius: 4)
                    .fill(clip.color.background)
                    .frame(width: 6, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(clip.preview)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    HStack(spacing: 5) {
                        Image(systemName: clip.type.icon).font(.caption2)
                        Text(clip.origin.label).font(.caption2)
                        Spacer()
                        Text(clip.createdAt, style: .relative).font(.caption2)
                        if clip.isPinned {
                            Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            if !isSelectMode { enterSelectMode(clip.id) }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { copyClip(clip) }
            Button(clip.isPinned ? "Unpin" : "Pin",
                   systemImage: clip.isPinned ? "pin.slash" : "pin") { clip.isPinned.toggle() }
            Button("Select", systemImage: "checkmark.circle") { enterSelectMode(clip.id) }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { context.delete(clip) }
        }
    }

    // MARK: - Actions

    private func copyClip(_ clip: Clip) {
        ClipboardService.write(clip: clip)
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
        let toDelete = allClips.filter { selectedIDs.contains($0.id) }
        toDelete.forEach { context.delete($0) }
        exitSelectMode()
    }

    private func copySelected() {
        let texts = allClips
            .filter { selectedIDs.contains($0.id) }
            .map { $0.content }
            .filter { !$0.isEmpty }
        guard !texts.isEmpty else { return }
        UIPasteboard.general.string = texts.joined(separator: "\n\n")
        exitSelectMode()
    }
}
