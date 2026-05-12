import SwiftUI

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    let snippets: [Snippet]
    let activeWorkspace: Workspace?
    let selectedCount: Int
    let activateWorkspace: (Workspace) -> Void
    let createWorkspace: () -> Void
    let renameWorkspace: (Workspace, String) -> Void
    let deleteWorkspace: (Workspace) -> Void
    let addSnippetToCanvas: (Snippet) -> Void
    let copySnippet: (Snippet) -> Void
    let openHistory: () -> Void
    let openSettings: () -> Void
    let openChat: () -> Void

    @State private var searchText = ""

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            ScrollView {
                VStack(spacing: 0) {
                    canvasSection
                    sectionDivider
                    clipsSection
                }
            }
            Divider()
            sidebarNavBar
        }
        .background(.regularMaterial)
    }

    // MARK: Header

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("ClipCanvas")
                .font(.headline)
            Spacer()
            Button(action: createWorkspace) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("New canvas")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var sectionDivider: some View {
        Divider().padding(.horizontal, 14).padding(.vertical, 6)
    }

    // MARK: Canvases

    private var canvasSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Canvases")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

            if workspaces.isEmpty {
                Text("No canvases yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 14)
            } else {
                ForEach(workspaces) { workspace in
                    WorkspaceRow(
                        workspace: workspace,
                        isActive: workspace.id == activeWorkspace?.id,
                        onTap: { activateWorkspace(workspace) },
                        onRename: { renameWorkspace(workspace, $0) },
                        onDelete: { deleteWorkspace(workspace) }
                    )
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: Clips

    private var clipsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Clips")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Spacer()
                if !snippets.isEmpty {
                    Text("\(snippets.count)")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("Search…", text: $searchText)
                    .font(.subheadline)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            if filteredSnippets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "Nothing copied yet" : "No matches")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(filteredSnippets) { snippet in
                        SidebarSnippetCard(
                            snippet: snippet,
                            addToCanvas: { addSnippetToCanvas(snippet) },
                            copy: { copySnippet(snippet) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .padding(.top, 10)
    }

    // MARK: Bottom nav

    private var sidebarNavBar: some View {
        HStack(spacing: 8) {
            SidebarNavButton(icon: "bubble.left.and.bubble.right", label: "Chats", action: openChat)
            SidebarNavButton(icon: "clock", label: "History", action: openHistory)
            SidebarNavButton(icon: "gearshape", label: "Settings", action: openSettings)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

// MARK: - Workspace row

private struct WorkspaceRow: View {
    let workspace: Workspace
    let isActive: Bool
    let onTap: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var renameDraft = ""

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 3, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.name)
                        .font(.subheadline)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundStyle(isActive ? .primary : .secondary)
                        .lineLimit(1)
                    Text("\(workspace.cards.count) card\(workspace.cards.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if isActive {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                renameDraft = workspace.name
                showRename = true
            }
            Divider()
            Button("Delete Canvas", systemImage: "trash", role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .alert("Rename Canvas", isPresented: $showRename) {
            TextField("Canvas name", text: $renameDraft)
            Button("Rename") {
                let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { onRename(trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \"\(workspace.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Canvas", role: .destructive) { onDelete() }
        } message: {
            Text("All cards on this canvas will be permanently deleted.")
        }
    }
}

// MARK: - Nav button

private struct SidebarNavButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
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
                    .help("Add to canvas")
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
        .background(snippet.cardVariant.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(snippet.cardVariant.accent.opacity(0.18), lineWidth: 1)
        }
        .contextMenu {
            Button("Add to Canvas", systemImage: "plus.square.on.square", action: addToCanvas)
            Button("Copy", systemImage: "doc.on.doc", action: copy)
        }
        .snippetDraggable(snippet)
    }
}
