import SwiftUI
import SwiftData

/// Resolves the active workspace and renders the canvas for it.
/// This is the single place that owns the workspace query and calls AppBootstrap.
struct CanvasHost: View {
    let onToggleSidebar: () -> Void
    var prefersInspector = false

    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }, sort: \Workspace.sortIndex)
    private var workspaces: [Workspace]

    @Environment(\.modelContext) private var context

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    var body: some View {
        Group {
            if let workspace = activeWorkspace {
                CanvasContainerView(
                    workspace: workspace,
                    onToggleSidebar: onToggleSidebar,
                    prefersInspector: prefersInspector
                )
            } else {
                AppLoadingScreen()
            }
        }
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
        // Also react when all workspaces are deleted while the view is already visible.
        .onChange(of: workspaces.isEmpty) { _, isEmpty in
            if isEmpty { AppBootstrap.ensureActiveWorkspace(in: context) }
        }
        .onAppear(perform: consumePendingRoute)
        .onReceive(NotificationCenter.default.publisher(for: .clipCanvasRouteRequested)) { note in
            guard let route = note.object as? AppRoute else { return }
            handleRoute(route)
        }
    }

    private func consumePendingRoute() {
        guard let route = AppRouteService.pendingRoute else { return }
        handleRoute(route)
    }

    private func handleRoute(_ route: AppRoute) {
        switch route {
        case .workspace(let id):
            if let workspace = workspaces.first(where: { $0.id == id }) {
                WorkspaceActionService.activate(workspace, among: workspaces)
            }
        case .object(let id):
            if let workspace = workspaces.first(where: { workspace in
                workspace.canvasObjects.contains { $0.id == id && $0.deletedAt == nil }
            }) {
                WorkspaceActionService.activate(workspace, among: workspaces)
            }
        case .clip, .chat:
            break
        }
    }
}

private struct AppLoadingScreen: View {
    var body: some View {
        ZStack {
            CanvasDotGrid(
                viewportOrigin: .zero,
                canvasScale: 1,
                boundsRadius: 900
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 6) {
                    Text("ClipCanvas")
                        .font(.title3.weight(.semibold))
                    Text("Preparing your canvas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .glassPanel(cornerRadius: 24, shadow: true, interactive: false)
        }
    }
}
