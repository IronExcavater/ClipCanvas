import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]
    @Query(
        filter: #Predicate<Workspace> { $0.isActive && !$0.isArchived },
        sort: [SortDescriptor(\Workspace.createdAt)]
    ) private var activeWorkspaces: [Workspace]
    @Query private var cards: [WorkspaceCard]

    @State private var searchText = ""
    @State private var feedback: String?

    private var activeWorkspace: Workspace? {
        activeWorkspaces.first
    }

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredSnippets.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Library is empty" : "No matches",
                        systemImage: "tray",
                        description: Text("Canvas captures and transform results appear here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredSnippets) { snippet in
                        LibraryRow(snippet: snippet)
                            .contextMenu {
                                Button("Copy", systemImage: "doc.on.doc") { copy(snippet) }
                                Button("Add to Active Canvas", systemImage: "rectangle.3.group") { addToCanvas(snippet) }
                                Divider()
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    delete(snippet)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(snippet)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    copy(snippet)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    addToCanvas(snippet)
                                } label: {
                                    Label("Canvas", systemImage: "rectangle.3.group")
                                }
                                .tint(.green)
                            }
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText)
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
        PasteboardService.writeString(snippet.text)
        showFeedback("Copied")
    }

    private func addToCanvas(_ snippet: Snippet) {
        guard let workspace = activeWorkspace ?? AppBootstrap.activeWorkspace(in: modelContext) else {
            showFeedback("No active workspace")
            return
        }
        let card = WorkspaceCard(snippet: snippet, x: 160, y: 180)
        card.workspace = workspace
        workspace.cards.append(card)
        workspace.updatedAt = Date()
        showFeedback("Added to canvas")
        dismiss()
    }

    private func delete(_ snippet: Snippet) {
        for card in cards where card.snippet?.id == snippet.id {
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snippet.type.icon)
                .frame(width: 28, height: 28)
                .background(Color.clipCanvasSecondaryBackground, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 6) {
                Text(snippet.preview)
                    .font(.body)
                    .lineLimit(3)
                HStack(spacing: 8) {
                    Text(snippet.captureMethod.label)
                    Text(snippet.createdAt, style: .relative)
                    if snippet.isMasked {
                        Label("Sensitive", systemImage: "lock.fill")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
