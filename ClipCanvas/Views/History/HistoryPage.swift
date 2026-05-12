import SwiftUI
import SwiftData

struct HistoryPage: View {
    @Query(
        filter: #Predicate<Clip> { $0.deletedAt == nil },
        sort: \Clip.updatedAt, order: .reverse
    ) private var clips: [Clip]

    @State private var filter = HistoryFilter()
    @State private var detailClip: Clip?

    private var filtered: [Clip] {
        clips
            .filter { filter.matches($0) }
            .sortedForPinnedRecency()
    }
    private var grouped: [(label: String, clips: [Clip])] { filtered.groupedByAge() }

    var body: some View {
        @Bindable var filter = filter
        List {
            AppSearchField(text: $filter.search, prompt: "Search history")
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            HistoryFilterBar(filter: filter)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if filtered.isEmpty {
                emptyState
            } else {
                ForEach(grouped, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.clips) { clip in
                            HistoryRow(
                                clip: clip,
                                onCopy: { ClipboardService.write(clip: clip) },
                                onTogglePin: { clip.isPinned.toggle() },
                                onDelete: { clip.softDelete() },
                                onDetails: { detailClip = clip }
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EmptyView()
            }
        }
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
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
            .listRowBackground(Color.clear)
        } else {
            ContentUnavailableView.search(text: filter.search)
                .listRowBackground(Color.clear)
        }
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
