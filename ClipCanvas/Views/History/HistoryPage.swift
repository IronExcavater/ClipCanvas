import SwiftUI
import SwiftData

struct HistoryPage: View {
    @Query(
        filter: #Predicate<Clip> { $0.deletedAt == nil },
        sort: \Clip.updatedAt, order: .reverse
    ) private var clips: [Clip]

    @State private var filter = HistoryFilter()
    @State private var detailClip: Clip?
    @State private var tagEditSelection: ClipTagEditSelection?
    @State private var isSelecting = false
    @State private var selectedClipIDs = Set<UUID>()
    @State private var searchPresented = false

    private var filtered: [Clip] {
        clips
            .filter { filter.matches($0) }
            .sortedForPinnedRecency()
    }
    private var grouped: [(label: String, clips: [Clip])] { filtered.groupedByAge() }
    private var selectedClips: [Clip] { clips.filter { selectedClipIDs.contains($0.id) } }

    var body: some View {
        let searchBinding = Binding(
            get: { filter.search },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.18)) {
                    filter.search = newValue
                }
            }
        )
        List {
            HistoryFilterBar(filter: filter)
                .appListItemRowInsets(vertical: 0)

            if filtered.isEmpty {
                emptyState
            } else {
                selectionControl
                    .appListItemRowInsets(vertical: 0)

                ForEach(grouped, id: \.label) { group in
                    Text(group.label)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                        .appListItemRowInsets(horizontal: 14, vertical: 1)

                    ForEach(group.clips) { clip in
                        ClipRowView(
                            clip: clip,
                            compact: false,
                            isSelecting: isSelecting,
                            isSelected: selectedClipIDs.contains(clip.id),
                            onSelect: { toggleSelection(clip) },
                            onDetails: { detailClip = clip }
                        )
                        .appListItemRowInsets(vertical: 3)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .listSectionSpacing(.compact)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: searchBinding, isPresented: $searchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search history")
        .animation(.easeInOut(duration: 0.18), value: filter.search.isEmpty)
        .animation(.easeInOut(duration: 0.18), value: searchPresented)
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
        .sheet(item: $tagEditSelection) { selection in
            NavigationStack {
                ScrollView {
                    ClipTagEditor(clips: selection.clips)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .navigationTitle("Tags")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if clips.isEmpty {
            ContentUnavailableView(
                "No History Yet",
                systemImage: "doc.on.clipboard",
                description: Text("Copy something to get started.")
            )
            .appEmptyStateRow()
        } else {
            ContentUnavailableView.search(text: filter.search)
                .appEmptyStateRow()
        }
    }

    private var selectionControl: some View {
        AppListSelectionControl(
            isSelecting: isSelecting,
            selectedCount: selectedClipIDs.count,
            selectTitle: "Select",
            onToggle: { isSelecting ? endSelection() : beginSelection() }
        ) {
            HStack(spacing: 2) {
                Button {
                    tagEditSelection = ClipTagEditSelection(clips: selectedClips)
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .appSelectionIconButtonStyle()
                .disabled(selectedClipIDs.isEmpty)

                Button(role: .destructive, action: deleteSelected) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .appSelectionIconButtonStyle()
                .disabled(selectedClipIDs.isEmpty)
            }
        }
    }

}

private extension HistoryPage {
    func toggleSelection(_ clip: Clip) {
        if selectedClipIDs.contains(clip.id) {
            selectedClipIDs.remove(clip.id)
        } else {
            selectedClipIDs.insert(clip.id)
        }
    }

    func deleteSelected() {
        selectedClips.forEach { ClipActionService.softDelete($0) }
        endSelection()
    }

    func beginSelection() {
        selectedClipIDs.removeAll()
        isSelecting = true
    }

    func endSelection() {
        selectedClipIDs.removeAll()
        isSelecting = false
    }
}

private extension [Clip] {
    func groupedByAge() -> [(label: String, clips: [Clip])] {
        let cal = Calendar.current
        let now = Date()
        var buckets: [(label: String, clips: [Clip])] = [
            ("Today", []), ("Yesterday", []), ("This Week", []), ("Older", [])
        ]
        for clip in self {
            if cal.isDateInToday(clip.updatedAt) { buckets[0].clips.append(clip) }
            else if cal.isDateInYesterday(clip.updatedAt) { buckets[1].clips.append(clip) }
            else if let floor = cal.date(byAdding: .day, value: -7, to: now), clip.updatedAt > floor {
                buckets[2].clips.append(clip)
            } else {
                buckets[3].clips.append(clip)
            }
        }
        return buckets.filter { !$0.clips.isEmpty }
    }
}

private struct ClipTagEditSelection: Identifiable {
    let id = UUID()
    let clips: [Clip]
}
