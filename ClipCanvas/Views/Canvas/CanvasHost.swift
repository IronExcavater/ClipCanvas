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
                ContentUnavailableView {
                    Label("No Workspace", systemImage: "rectangle.3.group")
                } description: {
                    Text("Create a workspace to get started.")
                } actions: {
                    Button("New Workspace") {
                        AppBootstrap.ensureActiveWorkspace(in: context)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
        // Also react when all workspaces are deleted while the view is already visible.
        .onChange(of: workspaces.isEmpty) { _, isEmpty in
            if isEmpty { AppBootstrap.ensureActiveWorkspace(in: context) }
        }
    }
}
