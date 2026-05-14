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
    @State private var expandedClipID: UUID?
    @State private var confirmingClearHistory = false
    @State private var feedback: String?
    @State private var feedbackToken = UUID()

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
            AppSearchSelectionBar(
                search: searchBinding,
                prompt: "Search clipboard",
                isSelecting: isSelecting,
                selectedCount: selectedClipIDs.count,
                onBeginSelection: beginSelection,
                onEndSelection: endSelection
            ) {
                Button(action: { tagEditSelection = ClipTagEditSelection(clips: selectedClips) }) {
                    AppToolbarCircleLabel(systemImage: "tag", size: 40, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selectedClipIDs.isEmpty)

                Button(role: .destructive, action: deleteSelected) {
                    AppToolbarCircleLabel(systemImage: "trash", size: 40, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selectedClipIDs.isEmpty)
            }
            .appListItemRowInsets(horizontal: 14, vertical: 4)

            HistoryFilterBar(filter: filter)
                .appListItemRowInsets(vertical: 0)

            if filtered.isEmpty {
                emptyState
            } else {
                ForEach(grouped, id: \.label) { group in
                    AppSectionHeader(title: group.label)
                        .appListItemRowInsets(horizontal: 14, vertical: 0)

                    ForEach(group.clips) { clip in
                        ClipRowView(
                            clip: clip,
                            compact: false,
                            isSelecting: isSelecting,
                            isSelected: selectedClipIDs.contains(clip.id),
                            isExpanded: expandedClipID == clip.id,
                            onSelect: { toggleSelection(clip) },
                            onDetails: { detailClip = clip },
                            onPrimaryAction: { handlePrimaryAction(clip) }
                        )
                        .appListItemRowInsets(vertical: 2)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .appListSectionSpacingCompact()
        .navigationTitle("Clipboard History")
        .animation(.easeInOut(duration: 0.18), value: filter.search.isEmpty)
        .animation(.easeInOut(duration: 0.18), value: expandedClipID)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarActions
            }
        }
        .overlay(alignment: .top) {
            FeedbackBanner(message: feedback ?? "")
                .opacity(feedback == nil ? 0 : 1)
                .offset(y: feedback == nil ? -12 : 10)
                .scaleEffect(feedback == nil ? 0.96 : 1)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: feedback)
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmingClearHistory, titleVisibility: .visible) {
            Button("Clear History", role: .destructive, action: clearHistory)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All clipboard history items will move to Recently Deleted.")
        }
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
        .sheet(item: $tagEditSelection) { selection in
            NavigationStack {
                ScrollView {
                    ClipTagEditor(clips: selection.clips)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                }
                .appScrollDismissesKeyboardInteractively()
                .navigationTitle("Tags")
                .appInlineNavigationTitleDisplayMode()
            }
            .appSheetPresentationDetents()
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

    @ViewBuilder
    private var toolbarActions: some View {
        Menu {
            Button("Clear History", systemImage: "trash", role: .destructive) {
                confirmingClearHistory = true
            }
            .disabled(clips.isEmpty)
        } label: {
            AppToolbarCircleLabel(systemImage: AppSymbol.options, size: 36, symbolSize: 18)
        }
        .accessibilityLabel("History options")
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

    func handlePrimaryAction(_ clip: Clip) {
        if expandedClipID == clip.id {
            expandedClipID = nil
        } else {
            ClipActionService.copy(clip)
            expandedClipID = clip.id
            showFeedback("Copied")
        }
    }

    func clearHistory() {
        ClipActionService.clearHistory(clips)
        expandedClipID = nil
        endSelection()
    }

    func deleteSelected() {
        selectedClips.forEach { ClipActionService.softDelete($0) }
        endSelection()
    }

    func beginSelection() {
        expandedClipID = nil
        selectedClipIDs.removeAll()
        isSelecting = true
    }

    func endSelection() {
        selectedClipIDs.removeAll()
        isSelecting = false
    }

    func showFeedback(_ message: String) {
        let token = UUID()
        feedbackToken = token
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            feedback = message
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                guard feedbackToken == token else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    feedback = nil
                }
            }
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

private struct ClipTagEditSelection: Identifiable {
    let id = UUID()
    let clips: [Clip]
}
