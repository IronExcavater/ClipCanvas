import SwiftUI
import SwiftData

struct SidebarView: View {
    let onClose: (() -> Void)?   // iPhone only: closes the overlay drawer

    @Query(sort: \Workspace.updatedAt, order: .reverse) private var workspaces: [Workspace]
    @Query(sort: \Clip.createdAt, order: .reverse) private var clips: [Clip]
    @Query(sort: \AIChat.updatedAt, order: .reverse) private var chats: [AIChat]
    @Environment(\.modelContext) private var context

    private var recentWorkspaces: [Workspace] { Array(workspaces.prefix(3)) }
    private var recentClips: [Clip] { Array(clips.prefix(5)) }
    private var recentChats: [AIChat] { Array(chats.prefix(3)) }

    var body: some View {
        NavigationStack {
            List {
                workspacesSection
                clipsSection
                chatsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ClipCanvas")
            .navigationBarTitleDisplayMode(.inline)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNav
        }
    }

    // MARK: - Workspaces section

    @ViewBuilder
    private var workspacesSection: some View {
        Section {
            ForEach(recentWorkspaces) { ws in
                WorkspaceRow(workspace: ws, onActivate: { activateWorkspace(ws) })
            }
            NavigationLink(destination: WorkspacesPage()) {
                Label("All Workspaces", systemImage: "rectangle.3.group")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } header: {
            Text("Workspaces")
        }
    }

    // MARK: - Clips section

    @ViewBuilder
    private var clipsSection: some View {
        Section {
            if clips.isEmpty {
                Text("Copy something to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(recentClips) { clip in
                    SidebarClipRow(clip: clip, onCopy: { copyClip(clip) })
                        .swipeActions(edge: .leading) {
                            Button {
                                clip.isPinned.toggle()
                            } label: {
                                Label(clip.isPinned ? "Unpin" : "Pin",
                                      systemImage: clip.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.delete(clip) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                NavigationLink(destination: ClipsPage()) {
                    Label("All Clips", systemImage: "doc.on.clipboard")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        } header: {
            Text("Recent Clips")
        }
    }

    // MARK: - Chats section

    @ViewBuilder
    private var chatsSection: some View {
        Section {
            if chats.isEmpty {
                Text("No chats yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(recentChats) { chat in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chat.title)
                            .font(.subheadline)
                        Text(chat.preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
                NavigationLink(destination: Text("All Chats — Phase 2")) {
                    Label("All Chats", systemImage: "bubble.left.and.bubble.right")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        } header: {
            Text("AI Chats")
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: 0) {
            if let onClose {
                navButton(icon: "scribble.variable", label: "Canvas", action: onClose)
            }
            Spacer()
            navButton(icon: "gear", label: "Settings") {
                // Phase 2: open settings sheet
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func navButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.caption2)
            }
            .foregroundStyle(.secondary)
            .frame(width: 56, height: 44)
        }
    }

    // MARK: - Actions

    private func activateWorkspace(_ workspace: Workspace) {
        workspaces.forEach { $0.isActive = ($0.id == workspace.id) }
    }

    private func copyClip(_ clip: Clip) {
        ClipboardService.write(clip: clip)
    }
}

// MARK: - Workspace row

private struct WorkspaceRow: View {
    let workspace: Workspace
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 10) {
                Image(systemName: workspace.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(workspace.isActive ? Color.accentColor : .secondary)
                    .font(.system(size: 17))
                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(workspace.placements.count) cards")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if workspace.isActive {
                    Text("Active")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sidebar clip row (compact)

private struct SidebarClipRow: View {
    let clip: Clip
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(clip.color.background)
                    .frame(width: 6, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.preview)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: clip.type.icon).font(.caption2)
                        Text(clip.createdAt, style: .relative).font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
