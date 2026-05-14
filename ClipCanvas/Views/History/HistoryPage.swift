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
            HistorySearchSelectionRow(
                search: searchBinding,
                isSelecting: isSelecting,
                selectedCount: selectedClipIDs.count,
                onBeginSelection: beginSelection,
                onEditTags: { tagEditSelection = ClipTagEditSelection(clips: selectedClips) },
                onDelete: deleteSelected,
                onDone: endSelection
            )
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

private struct HistorySearchSelectionRow: View {
    @Binding var search: String
    let isSelecting: Bool
    let selectedCount: Int
    let onBeginSelection: () -> Void
    let onEditTags: () -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isSelecting {
                Text("\(selectedCount) selected")
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onEditTags) {
                    AppToolbarCircleLabel(systemImage: "tag", size: 36, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)

                Button(role: .destructive, action: onDelete) {
                    AppToolbarCircleLabel(systemImage: "trash", size: 36, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)

                Button(action: onDone) {
                    AppToolbarCircleLabel(systemImage: "checkmark", size: 36, symbolSize: 15)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Search clipboard", text: $search)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                    if !search.isEmpty {
                        Button {
                            search = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)

                Button(action: onBeginSelection) {
                    AppToolbarCircleLabel(systemImage: "checklist", size: 40, symbolSize: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select")
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

    func handlePrimaryAction(_ clip: Clip) {
        if expandedClipID == clip.id {
            expandedClipID = nil
        } else {
            ClipActionService.copy(clip)
            expandedClipID = clip.id
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
