import SwiftUI

/// Layout shell. Decides iPhone overlay vs iPad/Mac split view.
/// Has no data dependencies — workspace resolution lives in CanvasHost.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var sidebarOpen = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        if hSizeClass == .compact { iPhoneLayout } else { splitLayout }
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
                        isOpen: sidebarOpen
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

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationStack {
                SidebarView(onClose: { columnVisibility = .detailOnly })
            }
        } detail: {
            CanvasHost(onToggleSidebar: {
                withAnimation {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                }
            })
        }
    }

    @ViewBuilder
    private var sidebarDrawerBackground: some View {
        if #available(iOS 26, *) {
            Rectangle()
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }
}
