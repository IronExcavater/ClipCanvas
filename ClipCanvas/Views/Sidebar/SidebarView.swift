import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var context

    let onClose: (() -> Void)?
    var isOpen = true
    var onOpenAIChat: ((AIChat) -> Void)?

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @Query(sort: \AIChat.updatedAt, order: .reverse) private var chats: [AIChat]

    @State private var renamingWorkspace: Workspace?
    @State private var renameText = ""
    @State private var renamingChat: AIChat?
    @State private var renameChatText = ""
    @State private var showRenameChatAlert = false

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var workspaceChats: [AIChat] {
        guard let activeWorkspace else { return [] }
        return Array(chats.filter { $0.workspace?.id == activeWorkspace.id }.prefix(4))
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List {
                currentWorkspaceSection
                librarySection
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

    private var currentWorkspaceSection: some View {
        Section {
            if let ws = activeWorkspace {
                WorkspaceRowView(
                    workspace: ws,
                    isRenaming: renamingWorkspace?.id == ws.id,
                    editingName: $renameText,
                    onActivate: { activateWorkspace(ws) },
                    onRename: { beginWorkspaceRename(ws) },
                    onCommitRename: { commitWorkspaceRename() },
                    onDelete: { WorkspaceActionService.softDelete(ws, among: workspaces) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        WorkspaceActionService.softDelete(ws, among: workspaces)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button { beginWorkspaceRename(ws) } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.accentColor)
                }
                .appListItemRowInsets(vertical: 3)
            } else {
                Text("Create a workspace to start")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .appListItemRowInsets(horizontal: 16, vertical: 2)
            }
        } header: {
            workspaceHeader
        }
    }

    private var librarySection: some View {
        Section {
            NavigationLink(destination: HistoryPage()) {
                sidebarNavRow(title: "Clipboard History", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.plain)
            .appListItemRowInsets(vertical: 3)

            NavigationLink(destination: WorkspacesPage()) {
                sidebarNavRow(title: "All Workspaces", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.plain)
            .appListItemRowInsets(vertical: 3)
        } header: {
            sectionHeader("Library", destination: HistoryPage())
        }
    }

    private var chatsSection: some View {
        Section {
            if workspaceChats.isEmpty {
                Text("No workspace chats yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .appListItemRowInsets(horizontal: 16, vertical: 2)
            } else {
                ForEach(workspaceChats) { chat in
                    Button {
                        onOpenAIChat?(chat)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chat.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(chat.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .appListCard(tint: .secondary, opacity: 0.06)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            context.delete(chat)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") {
                            beginChatRename(chat)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            context.delete(chat)
                        }
                    }
                    .appListItemRowInsets(vertical: 3)
                }
            }
        } header: {
            workspaceAIHeader
        }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 8) {
            NavigationLink(destination: WorkspacesPage()) {
                HStack(spacing: 8) {
                    Text("Workspace")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    viewAllLabel
                }
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(workspaces) { workspace in
                    Button {
                        activateWorkspace(workspace)
                    } label: {
                        Label(workspace.name, systemImage: workspace.id == activeWorkspace?.id ? "checkmark" : "square")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(BlendedIconButtonStyle(size: 34))
            .accessibilityLabel("Switch Workspace")

            Button(action: createWorkspace) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(BlendedIconButtonStyle(size: 34))
            .accessibilityLabel("New Workspace")
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private func sectionHeader<Destination: View>(_ title: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                viewAllLabel
            }
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private var workspaceAIHeader: some View {
        HStack(spacing: 8) {
            NavigationLink(destination: AIChatsPage()) {
                HStack(spacing: 8) {
                    Text("Workspace AI")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    viewAllLabel
                }
            }
            .buttonStyle(.plain)

            Button(action: createChat) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(BlendedIconButtonStyle(size: 34))
            .accessibilityLabel("New Chat")
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private var viewAllLabel: some View {
        HStack(spacing: 4) {
            Text("View all")
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.accentColor)
    }

    private func sidebarNavRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
        .appListCard(tint: .secondary, opacity: 0.06)
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
        commitChatRename()
    }

    private func beginChatRename(_ chat: AIChat) {
        renamingChat = chat
        renameChatText = chat.title
        showRenameChatAlert = true
    }

    private func commitChatRename() {
        let trimmed = renameChatText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let chat = renamingChat {
            chat.title = trimmed
            chat.updatedAt = Date()
        }
        renamingChat = nil
        renameChatText = ""
    }

    private func createWorkspace() {
        let ws = WorkspaceActionService.create(in: context, existing: workspaces)
        activateWorkspace(ws)
        beginWorkspaceRename(ws)
    }

    private func createChat() {
        let chat = AIChatService.createChat(in: context, workspace: activeWorkspace)
        onOpenAIChat?(chat)
    }
}
