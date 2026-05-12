import SwiftUI

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    let snippets: [Snippet]
    let activeWorkspace: Workspace?
    let selectedCount: Int
    let activateWorkspace: (Workspace) -> Void
    let createWorkspace: () -> Void
    let addSnippetToCanvas: (Snippet) -> Void
    let copySnippet: (Snippet) -> Void
    let openHistory: () -> Void

    @State private var searchText = ""

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            workspaceList
            Divider()
            recentHeader
            recentSnippetList
        }
        .background(.regularMaterial)
    }

    // MARK: Header

    private var sidebarHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(activeWorkspace?.name ?? "Canvas")
                    .font(.headline)
                    .lineLimit(1)
                Text("\(activeWorkspace?.cards.count ?? 0) cards")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: createWorkspace) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New workspace")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Workspace list — plain ScrollView rows, no List chrome

    private var workspaceList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(workspaces) { workspace in
                    WorkspaceRow(
                        workspace: workspace,
                        isActive: workspace.id == activeWorkspace?.id,
                        onTap: { activateWorkspace(workspace) }
                    )
                    if workspace.id != workspaces.last?.id {
                        Divider().padding(.leading, 38)
                    }
                }
            }
        }
        .frame(maxHeight: min(CGFloat(workspaces.count) * 52 + 8, 200))
    }

    // MARK: Recent snippets

    private var recentHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(snippets.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("All", action: openHistory)
                    .buttonStyle(.borderless)
                    .help("Open full history")
            }
            TextField("Search history", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var recentSnippetList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if filteredSnippets.isEmpty {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    ForEach(filteredSnippets) { snippet in
                        SidebarSnippetCard(
                            snippet: snippet,
                            addToCanvas: { addSnippetToCanvas(snippet) },
                            copy: { copySnippet(snippet) }
                        )
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Workspace row

private struct WorkspaceRow: View {
    let workspace: Workspace
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "rectangle.fill" : "rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 20)
                Text(workspace.name)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("\(workspace.cards.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Snippet card

private struct SidebarSnippetCard: View {
    let snippet: Snippet
    let addToCanvas: () -> Void
    let copy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            SourceGlyph(snippet: snippet)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(snippet.preview)
                        .font(snippet.type == .code ? .system(.caption, design: .monospaced) : .caption)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button(action: addToCanvas) {
                        Image(systemName: "plus").font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderless)
                }
                HStack(spacing: 4) {
                    Text(snippet.sourceTitle)
                    Text("·")
                    Text(snippet.createdAt, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if snippet.type == .image {
                    SnippetPreviewContent(snippet: snippet, lineLimit: 1, imageHeight: 82)
                }
            }
        }
        .padding(8)
        .background(snippet.cardVariant.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(snippet.cardVariant.accent.opacity(0.20), lineWidth: 1)
        }
        .contextMenu {
            Button("Add to Canvas", systemImage: "plus.square.on.square", action: addToCanvas)
            Button("Copy", systemImage: "doc.on.doc", action: copy)
        }
        .snippetDraggable(snippet)
    }
}
