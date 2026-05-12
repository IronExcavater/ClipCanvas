import SwiftUI
import SwiftData

struct SidebarView: View {
    let onClose: (() -> Void)?

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.updatedAt, order: .reverse
    ) private var workspaces: [Workspace]

    @Query(
        filter: #Predicate<Clip> { $0.deletedAt == nil },
        sort: \Clip.updatedAt, order: .reverse
    ) private var clips: [Clip]

    @Query(sort: \AIChat.updatedAt, order: .reverse) private var chats: [AIChat]

    @State private var detailClip: Clip?
    @State private var renamingWorkspace: Workspace?
    @State private var renameText = ""

    private var recentWorkspaces: [Workspace] { Array(workspaces.prefix(3)) }
    private var recentClips: [Clip] { Array(clips.sortedForPinnedRecency().prefix(5)) }
    private var recentChats: [AIChat] { Array(chats.prefix(3)) }

    var body: some View {
        List {
            sidebarHeader
            workspacesSection
            clipsSection
            chatsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNav
        }
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
    }

    private var sidebarHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ClipCanvas")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Workspaces, clips, and chats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .accessibilityLabel("Collapse Sidebar")
            }
        }
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Sections

    private var workspacesSection: some View {
        Section {
            ForEach(recentWorkspaces) { ws in
                WorkspaceRowView(
                    workspace: ws,
                    isRenaming: renamingWorkspace?.id == ws.id,
                    editingName: $renameText,
                    onActivate: { activateWorkspace(ws) },
                    onRename: { beginWorkspaceRename(ws) },
                    onCommitRename: { commitWorkspaceRename() },
                    onDelete: { ws.softDelete() }
                )
            }
        } header: {
            sectionHeader("Workspaces", destination: WorkspacesPage())
        }
    }

    private var clipsSection: some View {
        Section {
            if clips.isEmpty {
                Text("Copy something to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(recentClips) { clip in
                    ClipRowView(
                        clip: clip,
                        compact: true,
                        onCopy: { ClipboardService.write(clip: clip) },
                        onTogglePin: { clip.isPinned.toggle() },
                        onDelete: { clip.softDelete() },
                        onDetails: { detailClip = clip }
                    )
                }
            }
        } header: {
            sectionHeader("Recent Clips", destination: HistoryPage())
        }
    }

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
            }
        } header: {
            sectionHeader("AI Chats", destination: Text("All Chats - Phase 2"))
        }
    }

    private func sectionHeader<Destination: View>(_ title: String, destination: Destination) -> some View {
        HStack {
            Text(title)
            Spacer()
            NavigationLink(destination: destination) {
                Label("View \(title)", systemImage: "arrow.up.forward")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: 0) {
            NavigationLink(destination: TrashPage()) {
                Image(systemName: "trash")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 44)
            }
            .buttonStyle(.plain)
            Spacer()
            NavigationLink(destination: SettingsPage()) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func activateWorkspace(_ workspace: Workspace) {
        workspaces.forEach { $0.isActive = ($0.id == workspace.id) }
    }

    private func beginWorkspaceRename(_ workspace: Workspace) {
        renameText = workspace.name
        renamingWorkspace = workspace
    }

    private func commitWorkspaceRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            renamingWorkspace?.name = trimmed
            renamingWorkspace?.updatedAt = Date()
        }
        renamingWorkspace = nil
        renameText = ""
    }

}
