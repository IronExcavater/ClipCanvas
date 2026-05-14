import Foundation
import SwiftData

nonisolated struct AIWorkspaceToolCall: Codable, Equatable {
    var toolName: String
    var workspaceID: UUID
    var argumentsData: Data

    init<T: Encodable>(toolName: String, workspaceID: UUID, arguments: T) throws {
        self.toolName = toolName
        self.workspaceID = workspaceID
        self.argumentsData = try JSONEncoder().encode(arguments)
    }

    init(toolName: String, workspaceID: UUID, argumentsData: Data) {
        self.toolName = toolName
        self.workspaceID = workspaceID
        self.argumentsData = argumentsData
    }
}

enum AIWorkspaceToolExecutor {
    static func execute(
        _ call: AIWorkspaceToolCall,
        message: ChatMessage,
        in context: ModelContext,
        confirmed: Bool = false
    ) -> WorkspaceActionResult {
        let event = AIToolEvent(
            message: message,
            toolName: call.toolName,
            status: .running,
            summary: "Running \(displayName(for: call.toolName))",
            argumentsData: call.argumentsData
        )
        message.toolEvents.append(event)
        context.insert(event)

        guard let actionName = actionName(for: call.toolName) else {
            return finish(
                event,
                with: .failure("Unknown AI tool: \(call.toolName)"),
                status: .failed
            )
        }

        let request = WorkspaceActionRequest(
            name: actionName,
            workspaceID: call.workspaceID,
            argumentsData: call.argumentsData,
            source: .ai
        )
        let result = WorkspaceActionRegistry.perform(request, in: context, confirmed: confirmed)
        let status = status(for: result)
        return finish(event, with: result, status: status)
    }
}

private extension AIWorkspaceToolExecutor {
    static func actionName(for toolName: String) -> WorkspaceActionName? {
        WorkspaceActionName(rawValue: toolName) ?? snakeCaseActionNames[toolName]
    }

    static func status(for result: WorkspaceActionResult) -> AIToolEventStatus {
        if result.needsConfirmation { return .needsConfirmation }
        return result.success ? .completed : .failed
    }

    static func finish(
        _ event: AIToolEvent,
        with result: WorkspaceActionResult,
        status: AIToolEventStatus
    ) -> WorkspaceActionResult {
        event.status = status
        event.summary = result.message
        event.resultData = try? JSONEncoder().encode(result)
        if status == .completed || status == .failed {
            event.completedAt = Date()
        }
        return result
    }

    static func displayName(for toolName: String) -> String {
        toolName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
    }

    static let snakeCaseActionNames: [String: WorkspaceActionName] = [
        "canvas_create_sticky_note": .canvasCreateStickyNote,
        "canvas_create_clip_note": .canvasCreateClipNote,
        "canvas_update_object_text": .canvasUpdateObjectText,
        "canvas_move_objects": .canvasMoveObjects,
        "canvas_resize_objects": .canvasResizeObjects,
        "canvas_delete_objects": .canvasDeleteObjects,
        "canvas_duplicate_objects": .canvasDuplicateObjects,
        "canvas_create_connector": .canvasCreateConnector,
        "canvas_update_connector": .canvasUpdateConnector,
        "canvas_group_objects": .canvasGroupObjects,
        "canvas_ungroup_objects": .canvasUngroupObjects,
        "canvas_arrange_grid": .canvasArrangeGrid,
        "canvas_fit_view_to_content": .canvasFitViewToContent,
        "clip_apply_transform": .clipApplyTransform,
        "clip_update_content": .clipUpdateContent,
        "clip_add_tags": .clipAddTags,
        "clip_remove_tags": .clipRemoveTags,
        "chat_attach_objects": .chatAttachObjects,
        "workspace_create": .workspaceCreate,
        "workspace_delete": .workspaceDelete,
        "workspace_rename": .workspaceRename,
        "workspace_activate": .workspaceActivate,
    ]
}
