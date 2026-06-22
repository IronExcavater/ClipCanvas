import SwiftUI

/// Layout shell. Decides iPhone overlay vs iPad/Mac split view.
/// Has no data dependencies — workspace resolution lives in CanvasHost.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var sidebarOpen = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var activeAIChat: AIChat?
    @State private var sidebarPath: [SidebarDestination] = []

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceShellLayout.resolve(
                width: proxy.size.width,
                isCompactWidth: hSizeClass == .compact,
                prefersDesktopLayout: prefersDesktopLayout
            )

            Group {
                switch layout {
                case .overlayDrawer:
                    iPhoneLayout
                case .split, .splitWithInspector:
                    splitLayout(prefersInspector: layout.prefersInspector)
                }
            }
        }
        .sheet(item: $activeAIChat) { chat in
            AIChatDetailSheet(chat: chat)
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipCanvasRouteRequested)) { note in
            guard let route = note.object as? AppRoute else { return }
            handleRoute(route)
        }
    }

    // MARK: - iPhone: canvas-first + overlay sidebar drawer

    private var iPhoneLayout: some View {
        GeometryReader { proxy in
            let drawerWidth = min(proxy.size.width * 0.86, 360)
            ZStack(alignment: .leading) {
                CanvasHost(onToggleSidebar: { withAnimation { sidebarOpen.toggle() } })

                Color.black.opacity(sidebarOpen ? 0.35 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(sidebarOpen)
                    .onTapGesture { withAnimation { sidebarOpen = false } }

                NavigationStack(path: $sidebarPath) {
                    SidebarView(
                        onClose: { withAnimation { sidebarOpen = false } },
                        isOpen: sidebarOpen,
                        onOpenAIChat: openAIChatFromSidebar,
                        navigationPath: $sidebarPath
                    )
                    .navigationDestination(for: SidebarDestination.self) { destination in
                        SidebarDestinationContent(destination: destination)
                    }
                }
                .frame(width: drawerWidth)
                .background {
                    sidebarDrawerBackground
                }
                .ignoresSafeArea()
                .offset(x: sidebarOpen ? 0 : -drawerWidth)
                .shadow(color: .black.opacity(sidebarOpen ? 0.18 : 0), radius: 18, x: 8)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: sidebarOpen)
        }
    }

    // MARK: - iPad / Mac: NavigationSplitView

    private func splitLayout(prefersInspector: Bool) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationStack(path: $sidebarPath) {
                SidebarView(
                    onClose: { columnVisibility = .detailOnly },
                    onOpenAIChat: { activeAIChat = $0 },
                    navigationPath: $sidebarPath
                )
                .navigationDestination(for: SidebarDestination.self) { destination in
                    SidebarDestinationContent(destination: destination)
                }
            }
        } detail: {
            CanvasHost(onToggleSidebar: {
                withAnimation {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                }
            }, prefersInspector: prefersInspector)
        }
    }

    private var prefersDesktopLayout: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    private var sidebarDrawerBackground: some View {
        AppGlassSurface(shape: .rect(cornerRadius: 0))
    }

    private func openAIChatFromSidebar(_ chat: AIChat) {
        withAnimation {
            sidebarOpen = false
        }
        activeAIChat = chat
    }

    private func handleRoute(_ route: AppRoute) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            switch route {
            case .workspace, .object:
                sidebarPath.removeAll()
                sidebarOpen = false
                columnVisibility = .detailOnly
                activeAIChat = nil
            case .clip:
                sidebarPath = [.history]
                sidebarOpen = true
                columnVisibility = .all
                activeAIChat = nil
            case .chat:
                sidebarPath.removeAll()
                sidebarOpen = true
                columnVisibility = .all
            }
        }
    }
}

private struct SidebarDestinationContent: View {
    let destination: SidebarDestination

    var body: some View {
        switch destination {
        case .workspaces:
            WorkspacesPage()
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
