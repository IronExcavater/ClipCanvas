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
        ZStack(alignment: .leading) {
            CanvasHost(onToggleSidebar: { withAnimation { sidebarOpen.toggle() } })

            if sidebarOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { sidebarOpen = false } }
                    .transition(.opacity)

                NavigationStack {
                    SidebarView(onClose: { withAnimation { sidebarOpen = false } })
                }
                .frame(width: min(UIScreen.main.bounds.width * 0.86, 360))
                .background(.regularMaterial)
                .ignoresSafeArea()
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: sidebarOpen)
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
}
