import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)])
    private var workspaces: [Workspace]

    @State private var sidebarOpen = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    var body: some View {
        Group {
            if hSizeClass == .compact { iPhoneLayout } else { splitLayout }
        }
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
    }

    // MARK: - iPhone: canvas-first + overlay sidebar drawer

    private var iPhoneLayout: some View {
        ZStack(alignment: .leading) {
            canvas(onToggle: { sidebarOpen.toggle() })
                .ignoresSafeArea()

            if sidebarOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { sidebarOpen = false }
                    .transition(.opacity)

                NavigationStack {
                    SidebarView(onClose: { sidebarOpen = false })
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
                SidebarView(onClose: nil)
            }
        } detail: {
            canvas(onToggle: { columnVisibility = columnVisibility == .all ? .detailOnly : .all })
        }
    }

    // MARK: - Canvas (shared between both layouts)

    @ViewBuilder
    private func canvas(onToggle: @escaping () -> Void) -> some View {
        if let workspace = activeWorkspace {
            CanvasContainerView(workspace: workspace, onToggleSidebar: onToggle)
        } else {
            ContentUnavailableView("No workspace", systemImage: "rectangle.3.group",
                description: Text("Create a workspace to get started."))
        }
    }
}
