import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]
    @Query(
        filter: #Predicate<Workspace> { $0.isActive && !$0.isArchived },
        sort: [SortDescriptor(\Workspace.createdAt)]
    ) private var activeWorkspaces: [Workspace]

    @State private var searchText = ""
    @State private var feedback: String?

    private var activeWorkspace: Workspace? { activeWorkspaces.first }

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    // Groups snippets into date buckets for section headers.
    private var groupedSnippets: [(label: String, snippets: [Snippet])] {
        let calendar = Calendar.current
        let now = Date()
        var today: [Snippet] = []
        var yesterday: [Snippet] = []
        var thisWeek: [Snippet] = []
        var older: [Snippet] = []

        for snippet in filteredSnippets {
            if calendar.isDateInToday(snippet.createdAt) {
                today.append(snippet)
            } else if calendar.isDateInYesterday(snippet.createdAt) {
                yesterday.append(snippet)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      snippet.createdAt > weekAgo {
                thisWeek.append(snippet)
            } else {
                older.append(snippet)
            }
        }

        return [
            ("Today", today),
            ("Yesterday", yesterday),
            ("This Week", thisWeek),
            ("Older", older),
        ].filter { !$0.snippets.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredSnippets.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No clips yet" : "No matches",
                        systemImage: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                        description: searchText.isEmpty
                            ? Text("Copied text and images appear here automatically.")
                            : nil
                    )
                } else {
                    List {
                        summaryRow
                        ForEach(groupedSnippets, id: \.label) { group in
                            Section(group.label) {
                                ForEach(group.snippets) { snippet in
                                    HistoryRow(snippet: snippet, copy: { copy(snippet) }, addToCanvas: { addToCanvas(snippet) })
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) { delete(snippet) } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button { addToCanvas(snippet) } label: {
                                                Label("Canvas", systemImage: "plus.square")
                                            }
                                            .tint(.blue)
                                            Button { copy(snippet) } label: {
                                                Label("Copy", systemImage: "doc.on.doc")
                                            }
                                            .tint(.green)
                                        }
                                        .contextMenu {
                                            Button("Copy", systemImage: "doc.on.doc") { copy(snippet) }
                                            Button("Add to Canvas", systemImage: "rectangle.3.group") { addToCanvas(snippet) }
                                            Divider()
                                            Button("Delete", systemImage: "trash", role: .destructive) { delete(snippet) }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search clips…")
            .overlay(alignment: .top) {
                if let feedback {
                    Text(feedback)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: feedback != nil)
        }
    }

    // Summary row shows total counts at a glance.
    private var summaryRow: some View {
        HStack(spacing: 16) {
            Label("\(snippets.count) clips", systemImage: "doc.on.clipboard")
            let imageCount = snippets.filter { $0.type == .image }.count
            if imageCount > 0 {
                Label("\(imageCount) images", systemImage: "photo.on.rectangle")
            }
            let pinned = snippets.filter { $0.isPinned }.count
            if pinned > 0 {
                Label("\(pinned) pinned", systemImage: "pin")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .listRowBackground(Color.clear)
    }

    // MARK: Actions

    private func copy(_ snippet: Snippet) {
        PasteboardService.writeSnippet(snippet)
        showFeedback("Copied")
    }

    private func addToCanvas(_ snippet: Snippet) {
        guard let workspace = activeWorkspace ?? AppBootstrap.activeWorkspace(in: modelContext) else {
            showFeedback("No active workspace")
            return
        }
        let position = workspace.nextCardPosition()
        workspace.addCard(snippet: snippet, x: position.x, y: position.y)
        showFeedback("Added to canvas")
        dismiss()
    }

    private func delete(_ snippet: Snippet) {
        let cardDescriptor = FetchDescriptor<WorkspaceCard>()
        let allCards = (try? modelContext.fetch(cardDescriptor)) ?? []
        for card in allCards where card.snippet?.id == snippet.id {
            modelContext.delete(card)
        }
        modelContext.delete(snippet)
    }

    private func showFeedback(_ message: String) {
        withAnimation { feedback = message }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { feedback = nil }
        }
    }
}

// MARK: - Library row

private struct HistoryRow: View {
    let snippet: Snippet
    let copy: () -> Void
    let addToCanvas: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                SourceGlyph(snippet: snippet)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippet.sourceTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(snippet.createdAt, style: .relative)
                        if snippet.isMasked {
                            Label("Sensitive", systemImage: "lock.fill")
                                .foregroundStyle(.orange)
                        }
                        if snippet.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Copy", systemImage: "doc.on.doc", action: copy)
                    Button("Add to Canvas", systemImage: "rectangle.3.group", action: addToCanvas)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            SnippetPreviewContent(snippet: snippet, lineLimit: 4, imageHeight: 160)
        }
        .padding(.vertical, 6)
        .snippetDraggable(snippet)
        .listRowBackground(snippet.cardVariant.background.opacity(0.18))
    }
}
