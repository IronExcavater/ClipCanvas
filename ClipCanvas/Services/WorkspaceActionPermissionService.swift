import Foundation

nonisolated enum WorkspaceActionRisk: String, Codable {
    case safe
    case changesContent
    case destructive
}

nonisolated enum WorkspaceActionSource: String, Codable {
    case user
    case ai
    case appIntent
    case extensionImport
    case mcp
}

nonisolated enum WorkspaceActionName: String, Codable, CaseIterable {
    case canvasCreateStickyNote = "canvas.createStickyNote"
    case canvasCreateClipNote = "canvas.createClipNote"
    case canvasUpdateObjectText = "canvas.updateObjectText"
    case canvasMoveObjects = "canvas.moveObjects"
    case canvasResizeObjects = "canvas.resizeObjects"
    case canvasDeleteObjects = "canvas.deleteObjects"
    case canvasDuplicateObjects = "canvas.duplicateObjects"
    case canvasGroupObjects = "canvas.groupObjects"
    case canvasUngroupObjects = "canvas.ungroupObjects"
    case canvasArrangeGrid = "canvas.arrangeGrid"
    case canvasFitViewToContent = "canvas.fitViewToContent"
    case clipApplyTransform = "clip.applyTransform"
    case clipUpdateContent = "clip.updateContent"
    case clipAddTags = "clip.addTags"
    case clipRemoveTags = "clip.removeTags"
    case chatAttachObjects = "chat.attachObjects"

    case workspaceCreate = "workspace.create"
    case workspaceDelete = "workspace.delete"
    case workspaceRename = "workspace.rename"
    case workspaceActivate = "workspace.activate"
}

nonisolated struct WorkspaceActionValidation: Equatable {
    var isAllowed: Bool
    var risk: WorkspaceActionRisk
    var requiresConfirmation: Bool
    var message: String
}

enum WorkspaceActionPermissionService {
    static func validate(name: WorkspaceActionName, source: WorkspaceActionSource) -> WorkspaceActionValidation {
        if name.isWorkspaceManagement {
            return WorkspaceActionValidation(
                isAllowed: false,
                risk: name.risk,
                requiresConfirmation: false,
                message: "Workspace management is not available through shared workspace actions."
            )
        }

        return WorkspaceActionValidation(
            isAllowed: true,
            risk: name.risk,
            requiresConfirmation: source == .ai && name.risk == .destructive,
            message: "Allowed"
        )
    }
}

extension WorkspaceActionName {
    var risk: WorkspaceActionRisk {
        switch self {
        case .canvasDeleteObjects, .workspaceDelete:
            return .destructive
        case .canvasFitViewToContent, .chatAttachObjects:
            return .safe
        default:
            return .changesContent
        }
    }

    var isWorkspaceManagement: Bool {
        switch self {
        case .workspaceCreate, .workspaceDelete, .workspaceRename, .workspaceActivate:
            return true
        default:
            return false
        }
    }
}
