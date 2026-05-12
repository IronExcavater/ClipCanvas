import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        if hSizeClass == .compact {
            IPhoneRootView()
        } else {
            SplitRootView()
        }
    }
}

// MARK: - iPhone: canvas-first with overlay sidebar drawer

struct IPhoneRootView: View {
    @Query(sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)])
    private var workspaces: [Workspace]
    @Environment(\.modelContext) private var context

    @State private var sidebarOpen = false

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Canvas fills the full screen
            canvasDetail
                .ignoresSafeArea()

            // Scrim
            if sidebarOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeSidebar() }
                    .transition(.opacity)
            }

            // Sidebar drawer slides in from left
            if sidebarOpen {
                SidebarView(onClose: closeSidebar)
                    .frame(width: min(UIScreen.main.bounds.width * 0.86, 360))
                    .background(.regularMaterial)
                    .ignoresSafeArea()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: sidebarOpen)
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
    }

    @ViewBuilder
    private var canvasDetail: some View {
        if let workspace = activeWorkspace {
            CanvasContainerView(workspace: workspace, onToggleSidebar: toggleSidebar)
        } else {
            ContentUnavailableView("No workspace", systemImage: "rectangle.3.group",
                description: Text("Create a workspace to get started."))
        }
    }

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            sidebarOpen.toggle()
        }
    }

    private func closeSidebar() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            sidebarOpen = false
        }
    }
}

// MARK: - iPad / Mac: NavigationSplitView

struct SplitRootView: View {
    @Query(sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)])
    private var workspaces: [Workspace]
    @Environment(\.modelContext) private var context

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(onClose: nil)
        } detail: {
            canvasDetail
        }
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
    }

    @ViewBuilder
    private var canvasDetail: some View {
        if let workspace = activeWorkspace {
            CanvasContainerView(
                workspace: workspace,
                onToggleSidebar: { columnVisibility = columnVisibility == .all ? .detailOnly : .all }
            )
        } else {
            ContentUnavailableView("No workspace", systemImage: "rectangle.3.group",
                description: Text("Create a workspace to get started."))
        }
    }
}
