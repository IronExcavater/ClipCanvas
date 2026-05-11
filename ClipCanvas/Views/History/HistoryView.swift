import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss  // dismiss() closes this sheet

    // @Query fetches all snippets, newest first, and updates the list automatically on any change.
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

    var body: some View {
        NavigationStack {
            List {
                if filteredSnippets.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No clips" : "No matches",
                        systemImage: "tray"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        HStack {
                            Label("\(filteredSnippets.count) clips", systemImage: "clock")
                            Spacer()
                            Text("\(filteredSnippets.filter { $0.type == .image }.count) images")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    ForEach(filteredSnippets) { snippet in
                        LibraryRow(snippet: snippet, copy: { copy(snippet) }, addToCanvas: { addToCanvas(snippet) })
                            .contextMenu {
                                Button("Copy", systemImage: "doc.on.doc") { copy(snippet) }
                                Button("Add to Canvas", systemImage: "rectangle.3.group") { addToCanvas(snippet) }
                                Divider()
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(snippet) }
                            }
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText)  // adds a search bar that binds to searchText
            .overlay(alignment: .top) {
                if let feedback {
                    Text(feedback)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
        }
    }

    private func copy(_ snippet: Snippet) {
        PasteboardService.writeSnippet(snippet)
        showFeedback("Copied")
    }

    private func addToCanvas(_ snippet: Snippet) {
        guard let workspace = activeWorkspace ?? AppBootstrap.activeWorkspace(in: modelContext) else {
            showFeedback("No active workspace")
            return
        }
        // Use the stagger helper so library items don't pile on top of each other.
        let position = workspace.nextCardPosition()
        workspace.addCard(snippet: snippet, x: position.x, y: position.y)
        showFeedback("Added to canvas")
        dismiss()
    }

    private func delete(_ snippet: Snippet) {
        // Deleting a Snippet sets WorkspaceCard.snippet to nil rather than deleting the card
        // (the cascade rule runs Workspace → Card, not Snippet → Card). ExpiryService cleans
        // up orphaned cards on the next app activation, but we also clean up here immediately.
        let cardDescriptor = FetchDescriptor<WorkspaceCard>()
        let allCards = (try? modelContext.fetch(cardDescriptor)) ?? []
        for card in allCards where card.snippet?.id == snippet.id {
            modelContext.delete(card)
        }
        modelContext.delete(snippet)
        showFeedback("Deleted")
    }

    private func showFeedback(_ message: String) {
        withAnimation { feedback = message }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { feedback = nil }
        }
    }
}

private struct LibraryRow: View {
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
                        Text(snippet.createdAt, style: .relative)  // e.g. "3 minutes ago"
                        if snippet.isMasked {
                            Label("Sensitive", systemImage: "lock.fill")
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
                }
                .buttonStyle(.borderless)
            }

            SnippetPreviewContent(snippet: snippet, lineLimit: 5, imageHeight: 180)
        }
        .padding(.vertical, 6)
        .snippetDraggable(snippet)  // makes this row draggable to the canvas
        .listRowBackground(snippet.cardVariant.background.opacity(0.20))
    }
}
