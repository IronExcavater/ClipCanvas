import Foundation
import SwiftData

enum WorkspaceActionService {
    static func activate(_ workspace: Workspace, among workspaces: [Workspace]) {
        workspaces.forEach { $0.isActive = ($0.id == workspace.id) }
    }

    @discardableResult
    static func create(in context: ModelContext, existing workspaces: [Workspace], name: String? = nil) -> Workspace {
        let workspace = Workspace(
            name: name ?? "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        )
        workspaces.forEach { $0.isActive = false }
        context.insert(workspace)
        return workspace
    }

    static func rename(_ workspace: Workspace?, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let workspace, workspace.name != trimmed else { return }
        workspace.name = trimmed
        workspace.updatedAt = Date()
    }

    static func softDelete(_ workspace: Workspace, among workspaces: [Workspace]) {
        if workspace.isActive, let next = workspaces.first(where: { $0.id != workspace.id && $0.deletedAt == nil }) {
            next.isActive = true
        }
        workspace.softDelete()
    }
}
