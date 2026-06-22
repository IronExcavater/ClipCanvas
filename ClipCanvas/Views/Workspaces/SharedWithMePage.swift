import SwiftData
import SwiftUI

struct SharedWithMePage: View {
    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil && $0.isCollaborative == true }, sort: \Workspace.updatedAt, order: .reverse)
    private var sharedWorkspaces: [Workspace]

    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }, sort: \Workspace.sortIndex)
    private var allWorkspaces: [Workspace]

    var body: some View {
        List {
            if sharedWorkspaces.isEmpty {
                ContentUnavailableView(
                    "No Shared Workspaces",
                    systemImage: "person.2",
                    description: Text("Collaborative workspaces shared to ClipCanvas will appear here.")
                )
                .appEmptyStateRow()
            }

            ForEach(sharedWorkspaces) { workspace in
                WorkspaceRow(
                    workspace: workspace,
                    isRenaming: false,
                    editingName: .constant(""),
                    onActivate: { WorkspaceActionService.activate(workspace, among: allWorkspaces) },
                    onRename: {},
                    onCommitRename: {},
                    onDelete: { WorkspaceActionService.softDelete(workspace, among: allWorkspaces) }
                )
                .appListItemRowInsets(vertical: 3)
            }
        }
        .appPageListStyle()
        .navigationTitle("Shared With Me")
        .appInlineNavigationTitleDisplayMode()
    }
}
