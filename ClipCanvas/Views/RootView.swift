import SwiftUI

/// Layout shell. Decides iPhone overlay vs iPad/Mac split view.
/// Has no data dependencies — workspace resolution lives in CanvasHost.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var sidebarOpen = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var activeAIChat: AIChat?

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

                NavigationStack {
                    SidebarView(
                        onClose: { withAnimation { sidebarOpen = false } },
                        isOpen: sidebarOpen,
                        onOpenAIChat: openAIChatFromSidebar
                    )
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
            NavigationStack {
                SidebarView(
                    onClose: { columnVisibility = .detailOnly },
                    onOpenAIChat: { activeAIChat = $0 }
                )
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
}
