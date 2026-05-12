import SwiftUI
import SwiftData

/// Resolves the active workspace and renders the canvas for it.
/// This is the single place that owns the workspace query and calls AppBootstrap.
struct CanvasHost: View {
    let onToggleSidebar: () -> Void

    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }, sort: \Workspace.sortIndex)
    private var workspaces: [Workspace]

    @Environment(\.modelContext) private var context

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    var body: some View {
        Group {
            if let workspace = activeWorkspace {
                CanvasContainerView(workspace: workspace, onToggleSidebar: onToggleSidebar)
            } else {
                ContentUnavailableView(
                    "No Workspace",
                    systemImage: "rectangle.3.group",
                    description: Text("Create a workspace to get started.")
                )
            }
        }
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
    }
}
