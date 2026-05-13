import SwiftUI
import SwiftData

struct SidebarView: View {
    let onClose: (() -> Void)?
    var isOpen = true

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
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
        VStack(spacing: 0) {
            sidebarHeader

            List {
                workspacesSection
                clipsSection
                chatsSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 8, for: .scrollContent)
            .listSectionSpacing(.compact)
            .listSectionSeparator(.hidden)
            .mask(VerticalEdgeFadeMask(top: 10, bottom: 24))

            bottomNav
        }
        .background {
            sidebarBackground
                .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
        .onChange(of: isOpen) { _, newValue in
            if !newValue { finishRenaming() }
        }
    }

    private var sidebarHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ClipCanvas")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                Text("Capture, arrange, and reuse ideas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if onClose != nil {
                Button(action: closeSidebar) {
                    Image(systemName: AppSymbol.sidebar)
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(BlendedIconButtonStyle())
                .accessibilityLabel("Collapse Sidebar")
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
        .padding(.leading, 16)
        .padding(.trailing, 12)
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
                    onDelete: { WorkspaceActionService.softDelete(ws, among: workspaces) }
                )
                .appListItemRowInsets(vertical: 3)
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
                    .appListItemRowInsets(horizontal: 16, vertical: 2)
            } else {
                ForEach(recentClips) { clip in
                    ClipRowView(
                        clip: clip,
                        compact: true,
                        onDetails: { detailClip = clip }
                    )
                    .appListItemRowInsets(vertical: 3)
                }
            }
        } header: {
            sectionHeader("Recent Clipboard", destination: HistoryPage())
        }
    }

    private var chatsSection: some View {
        Section {
            if chats.isEmpty {
                Text("No chats yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .appListItemRowInsets(horizontal: 16, vertical: 2)
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
                    .appListCard(tint: .secondary, opacity: 0.08)
                    .appListItemRowInsets(vertical: 3)
                }
            }
        } header: {
            sectionHeader("AI Chats", destination: AIChatsPage())
        }
    }

    private func sectionHeader<Destination: View>(_ title: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    Text("View all")
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .padding(.vertical, 4)
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: 0) {
            NavigationLink(destination: TrashPage()) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(BlendedIconButtonStyle())
            Spacer()
            NavigationLink(destination: SettingsPage()) {
                Image(systemName: AppSymbol.settings)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(BlendedIconButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 24)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if #available(iOS 26, *) {
            Rectangle()
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }

    private func closeSidebar() {
        finishRenaming()
        onClose?()
    }

    private func activateWorkspace(_ workspace: Workspace) {
        WorkspaceActionService.activate(workspace, among: workspaces)
    }

    private func beginWorkspaceRename(_ workspace: Workspace) {
        renameText = workspace.name
        renamingWorkspace = workspace
    }

    private func commitWorkspaceRename() {
        finishRenaming()
    }

    private func finishRenaming() {
        WorkspaceActionService.rename(renamingWorkspace, to: renameText)
        renamingWorkspace = nil
        renameText = ""
    }
}
