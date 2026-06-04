import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var context

    let onClose: (() -> Void)?
    var isOpen = true
    var onOpenAIChat: ((AIChat) -> Void)?
    @State private var iCloudStatus: ICloudProfileStatus = .checking
    @State private var navigatesToSettings = false

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
                Section {
                    if workspaceChats.isEmpty {
                        ContentUnavailableView(
                            "No AI Chats",
                            systemImage: "sparkles",
                            description: Text("Chats for the current workspace appear here.")
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
        .onAppear {
            refreshICloudStatus()
        }
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

            Text("Active workspace")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            HStack(alignment: .center, spacing: 8) {
                Text(activeWorkspace?.name ?? "Choose a workspace")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .accessibilityLabel("Switch Workspace")

                NavigationLink(destination: WorkspacesPage()) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(BlendedIconButtonStyle())
                .foregroundStyle(.primary)
                .accessibilityLabel("View All Workspaces")
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
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.top, 8)
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: 12) {
            Button {
                if iCloudStatus == .noAccount {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                } else {
                    navigatesToSettings = true
                }
            } label: {
                iCloudProfile
            }
            .buttonStyle(.plain)
            .accessibilityLabel("iCloud profile")
            .navigationDestination(isPresented: $navigatesToSettings) {
                SettingsPage()
            }

            Spacer(minLength: 10)

            sidebarNavButton(destination: HistoryPage(), systemImage: "clipboard")
            sidebarNavButton(destination: TrashPage(), systemImage: "trash")
            sidebarNavButton(destination: SettingsPage(), systemImage: AppSymbol.settings)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 24)
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

    private func sidebarNavButton<Destination: View>(destination: Destination, systemImage: String) -> some View {
        NavigationLink(destination: destination) {
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
        Rectangle().glassPanel(cornerRadius: 0, shadow: false)
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
        iCloudStatus = FileManager.default.ubiquityIdentityToken == nil ? .noAccount : .available
    }
}

private enum ICloudProfileStatus {
    case checking
    case available
    case noAccount
    case unavailable
}
