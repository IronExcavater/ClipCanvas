import SwiftUI

// WorkspaceSidebar receives all its data and actions from WorkspaceView via plain let
// properties and closures — it owns no state of its own except the search field.
// This keeps it a "dumb" view: easy to test and reason about in isolation.
struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    let snippets: [Snippet]
    let activeWorkspace: Workspace?
    let selectedCount: Int
    let activateWorkspace: (Workspace) -> Void
    let createWorkspace: () -> Void
    let addSnippetToCanvas: (Snippet) -> Void
    let copySnippet: (Snippet) -> Void
    let openLibrary: () -> Void

    @State private var searchText = ""

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceSidebarHeader(
                activeWorkspace: activeWorkspace,
                createWorkspace: createWorkspace,
                openLibrary: openLibrary
            )
            WorkspaceList(
                workspaces: workspaces,
                activeWorkspace: activeWorkspace,
                activateWorkspace: activateWorkspace
            )
            Divider()
            RecentSnippetsHeader(
                snippetCount: snippets.count,
                searchText: $searchText,
                openLibrary: openLibrary
            )
            RecentSnippetList(
                snippets: filteredSnippets,
                addSnippetToCanvas: addSnippetToCanvas,
                copySnippet: copySnippet
            )
        }
        .background(.regularMaterial)   // frosted glass that adapts to light/dark mode
    }
}

private struct WorkspaceSidebarHeader: View {
    let activeWorkspace: Workspace?
    let createWorkspace: () -> Void
    let openLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                HStack(spacing: 6) {
                    Button(action: createWorkspace) { Image(systemName: "plus") }
                    Button(action: openLibrary)     { Image(systemName: "clock") }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct WorkspaceList: View {
    let workspaces: [Workspace]
    let activeWorkspace: Workspace?
    let activateWorkspace: (Workspace) -> Void

    var body: some View {
        List {
            ForEach(workspaces) { workspace in
                WorkspaceSidebarRow(workspace: workspace, isActive: workspace.id == activeWorkspace?.id)
                    .contentShape(Rectangle())  // makes the full row tappable, not just the text
                    .onTapGesture { activateWorkspace(workspace) }
            }
        }
        .listStyle(.sidebar)
        // Cap the workspace list height so the recent snippet section is always visible.
        .frame(height: min(CGFloat(max(workspaces.count, 1)) * 44 + 12, 156))
    }
}

private struct RecentSnippetsHeader: View {
    let snippetCount: Int
    @Binding var searchText: String
    let openLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: openLibrary) { Image(systemName: "arrow.up.forward.app") }
                    .buttonStyle(.borderless)
                    .help("Open history")
                Text("\(snippetCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Search history", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct RecentSnippetList: View {
    let snippets: [Snippet]
    let addSnippetToCanvas: (Snippet) -> Void
    let copySnippet: (Snippet) -> Void

    var body: some View {
        ScrollView {
            // LazyVStack only creates rows as they scroll into frame — important for
            // long snippet lists where creating all views upfront would be slow.
            LazyVStack(spacing: 6) {
                if snippets.isEmpty {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ForEach(snippets) { snippet in
                        SnippetLibraryCard(
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

private struct WorkspaceSidebarRow: View {
    let workspace: Workspace
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name).lineLimit(1)
                Text("\(workspace.cards.count) cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct SnippetLibraryCard: View {
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
        .snippetDraggable(snippet)  // drag this card onto the canvas
    }
}
