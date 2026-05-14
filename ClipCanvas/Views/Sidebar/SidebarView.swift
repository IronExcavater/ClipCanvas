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
                if workspaceChats.isEmpty {
                    ContentUnavailableView(
                        "No AI Chats",
                        systemImage: "sparkles",
                        description: Text("Chats for the current workspace appear here.")
                    )
                    .appEmptyStateRow()
                } else {
                    ForEach(workspaceChats) { chat in
                        sidebarChatRow(chat)
                            .appListItemRowInsets(vertical: 3)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 8, for: .scrollContent)
            .appListSectionSpacingCompact()
            .listSectionSeparator(.hidden)
            .mask(VerticalEdgeFadeMask(top: 10, bottom: 24))

            bottomNav
        }
        .background {
            sidebarBackground
                .ignoresSafeArea()
        }
        .appHideNavigationBarIfAvailable()
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipCanvas")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    Text("Capture, arrange, and reuse ideas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: createChat) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(BlendedIconButtonStyle(size: 38))
                .accessibilityLabel("New AI Chat")

                if onClose != nil {
                    Button(action: closeSidebar) {
                        Image(systemName: AppSymbol.sidebar)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(BlendedIconButtonStyle(size: 38))
                    .accessibilityLabel("Collapse Sidebar")
                }
            }

            HStack(spacing: 8) {
                Text(activeWorkspace?.name ?? "Choose a workspace")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                NavigationLink(destination: WorkspacesPage()) {
                    HStack(spacing: 3) {
                        Text("View all")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                }
                .buttonStyle(.plain)
                .background(.thinMaterial, in: Capsule())
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
        .padding(.leading, 16)
        .padding(.trailing, 12)
    }

    // MARK: - Chats

    private func sidebarChatRow(_ chat: AIChat) -> some View {
        Button {
            onOpenAIChat?(chat)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: chat.mode == .thinking ? "brain" : "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor.opacity(0.14), in: Circle())

                    Text(chat.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    RelativeAgeText(date: chat.updatedAt, suffix: " ago")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.62))
                }

                Text(chat.preview)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.78))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Label("\(chat.sortedMessages.count)", systemImage: "bubble.left.and.bubble.right")
                    Label("\(chat.sortedMessages.flatMap(\.sortedAttachments).count)", systemImage: "paperclip")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.78))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                context.delete(chat)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
                context.delete(chat)
            }
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: 0) {
            NavigationLink(destination: HistoryPage()) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(BlendedIconButtonStyle())
            Spacer()
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
        onClose?()
    }

    private func activateWorkspace(_ workspace: Workspace) {
        WorkspaceActionService.activate(workspace, among: workspaces)
    }

    private func createChat() {
        let chat = AIChatService.createChat(in: context, workspace: activeWorkspace)
        onOpenAIChat?(chat)
    }
}
