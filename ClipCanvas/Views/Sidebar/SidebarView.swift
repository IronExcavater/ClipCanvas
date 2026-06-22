import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

enum SidebarDestination: Hashable {
    case workspaces
    case sharedWithMe
    case history
    case trash
    case settings
    case iCloudProfile
}

struct SidebarView: View {
    @Environment(\.modelContext) private var context

    let onClose: (() -> Void)?
    var isOpen = true
    var onOpenAIChat: ((AIChat) -> Void)?
    @Binding var navigationPath: [SidebarDestination]
    @State private var iCloudStatus: ICloudProfileStatus = .checking

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @Query(
        filter: #Predicate<AIChat> { $0.deletedAt == nil },
        sort: \AIChat.updatedAt,
        order: .reverse
    ) private var chats: [AIChat]

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var workspaceChats: [AIChat] {
        guard let activeWorkspace else { return [] }
        return Array(chats.filter { $0.workspace?.id == activeWorkspace.id }.prefix(4))
    }

    private var activeWorkspaceChatCount: Int {
        guard let activeWorkspace else { return 0 }
        return chats.filter { $0.workspace?.id == activeWorkspace.id }.count
    }

    private var activeWorkspaceVisibleCardCount: Int {
        activeWorkspace?.canvasObjects.filter(\.isCanvasContent).count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List {
                Section {
                    if workspaceChats.isEmpty {
                        ContentUnavailableView(
                            "No AI Chats",
                            systemImage: "sparkles"
                        )
                        .appEmptyStateRow()
                    } else {
                        ForEach(workspaceChats) { chat in
                            AIChatPreviewRow(chat: chat, onOpen: { onOpenAIChat?(chat) })
                                .appListItemRowInsets(vertical: 3)
                        }
                    }
                } header: {
                    sidebarSectionTitle("AI Chats")
                }
            }
            .appSidebarListStyle()
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 8, for: .scrollContent)
            .appListSectionSpacingCompact()
            .listSectionSeparator(.hidden)
            .mask(VerticalEdgeFadeMask(top: 10, bottom: 24))
            .frame(maxHeight: .infinity)

            bottomNav
        }
        .background {
            sidebarBackground
                .ignoresSafeArea()
        }
        .appHideNavigationBarIfAvailable()
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            refreshICloudStatus()
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("ClipCanvas")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: createChat) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .accessibilityLabel("New AI Chat")

                if onClose != nil {
                    Button(action: closeSidebar) {
                        Image(systemName: AppSymbol.sidebar)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(BlendedIconButtonStyle())
                    .accessibilityLabel("Collapse Sidebar")
                }
            }

            HStack(spacing: 8) {
                if workspaces.count > 1 {
                    Menu {
                        ForEach(workspaces) { workspace in
                            Button {
                                activateWorkspace(workspace)
                            } label: {
                                Label(
                                    workspace.name,
                                    systemImage: workspace.id == activeWorkspace?.id ? "checkmark" : "folder"
                                )
                            }
                        }
                    } label: {
                        SidebarActiveWorkspaceSummary(
                            name: activeWorkspace?.name ?? "Choose a workspace",
                            cardCount: activeWorkspaceVisibleCardCount,
                            chatCount: activeWorkspaceChatCount,
                            updatedAt: activeWorkspace?.updatedAt,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Switch Workspace")
                } else {
                    SidebarActiveWorkspaceSummary(
                        name: activeWorkspace?.name ?? "Choose a workspace",
                        cardCount: activeWorkspaceVisibleCardCount,
                        chatCount: activeWorkspaceChatCount,
                        updatedAt: activeWorkspace?.updatedAt,
                        showsDisclosure: false
                    )
                }

                sidebarNavButton(destination: .workspaces, systemImage: "rectangle.3.group")
                    .accessibilityLabel("Workspaces")
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
        .padding(.leading, 16)
        .padding(.trailing, 12)
    }

    // MARK: - Chats

    private func sidebarSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(.primary.opacity(0.82))
            .padding(.leading, 4)
            .padding(.top, 8)
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if iCloudStatus == .noAccount {
                    #if canImport(UIKit)
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    #else
                    navigationPath.append(.iCloudProfile)
                    #endif
                } else {
                    navigationPath.append(.iCloudProfile)
                }
            } label: {
                iCloudProfile
            }
            .buttonStyle(.plain)
            .accessibilityLabel("iCloud profile")

            HStack(spacing: 12) {
                Spacer(minLength: 0)
                sidebarNavButton(destination: .history, systemImage: "clipboard")
                sidebarNavButton(destination: .sharedWithMe, systemImage: "person.2")
                sidebarNavButton(destination: .trash, systemImage: "trash")
                sidebarNavButton(destination: .settings, systemImage: AppSymbol.settings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(.regularMaterial)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var iCloudProfile: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 46, height: 46)
                    .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Circle())
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 5)

                Circle()
                    .fill(iCloudStatusColor)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.platformSystemBackground, lineWidth: 2))
                    .offset(x: -2, y: -2)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("iCloud")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(iCloudStatusText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Capsule())
    }

    private func sidebarNavButton(destination: SidebarDestination, systemImage: String) -> some View {
        NavigationLink(value: destination) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .buttonStyle(BlendedIconButtonStyle())
    }

    private var iCloudStatusText: String {
        switch iCloudStatus {
        case .available:
            return "Sync on"
        case .noAccount:
            return "Sign in"
        case .unavailable:
            return "Unavailable"
        case .checking:
            return "Checking"
        }
    }

    private var iCloudStatusColor: Color {
        switch iCloudStatus {
        case .available:
            return .green
        case .noAccount:
            return .orange
        case .unavailable, .checking:
            return .secondary
        }
    }

    private var sidebarBackground: some View {
        #if os(macOS)
        Color.clear
        #else
        ZStack {
            Color.platformSystemBackground
            Color.platformSecondarySystemBackground.opacity(0.72)
            AppGlassSurface(
                shape: .rect(cornerRadius: 0),
                tint: Color.platformSystemBackground.opacity(0.18)
            )
        }
        #endif
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

    private func refreshICloudStatus() {
        iCloudStatus = ICloudAccountService.currentStatus()
    }

    @ViewBuilder
    func destinationView(for destination: SidebarDestination) -> some View {
        switch destination {
        case .workspaces:
            WorkspacesPage()
        case .sharedWithMe:
            SharedWithMePage()
        case .history:
            HistoryPage()
        case .trash:
            TrashPage()
        case .settings:
            SettingsPage()
        case .iCloudProfile:
            ICloudProfilePage()
        }
    }
}

private struct SidebarActiveWorkspaceSummary: View {
    let name: String
    let cardCount: Int
    let chatCount: Int
    let updatedAt: Date?
    var showsDisclosure = true

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                AppIconBadge(systemImage: "folder.fill", size: 26, iconSize: 13, color: .accentColor)

                Text(name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showsDisclosure {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Label("\(cardCount)", systemImage: "rectangle.stack")
                Label("\(chatCount)", systemImage: "sparkles")
                Spacer(minLength: 0)
                if let updatedAt {
                    RelativeAgeText(date: updatedAt, suffix: " ago")
                }
            }
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16, shadow: false, interactive: true)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
