import Foundation
import SwiftData

enum AIChatCommandRouter {
    static func respond(to userMessage: ChatMessage, with assistantMessage: ChatMessage, in context: ModelContext) async {
        guard let chat = userMessage.chat ?? assistantMessage.chat,
              let workspace = chat.workspace else {
            finish(assistantMessage, content: "Open this chat from a workspace so I can inspect and update canvas cards.")
            return
        }

        assistantMessage.status = .streaming
        let command = Command(message: userMessage.content)

        switch command {
        case .transform(let skill):
            let result = runTransform(skillID: skill.id, chat: chat, workspace: workspace, message: assistantMessage, in: context)
            finish(assistantMessage, content: skill.completion(for: result))
        case .arrangeGrid:
            let objects = targetObjects(chat: chat, workspace: workspace)
            guard !objects.isEmpty else {
                finish(assistantMessage, content: "There are no canvas cards to arrange.")
                return
            }
            let columns = max(1, Int(ceil(sqrt(Double(objects.count)))))
            let arguments = WorkspaceArrangeGridArguments(
                objectIDs: objects.map(\.id),
                originX: 0,
                originY: 0,
                columnCount: columns,
                horizontalSpacing: 22,
                verticalSpacing: 22
            )
            let result = execute(
                toolName: "canvas_arrange_grid",
                workspaceID: workspace.id,
                arguments: arguments,
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Arranged \(objects.count) cards into a grid." : result.message)
        case .createNote(let text):
            let arguments = WorkspaceCreateStickyNoteArguments(
                text: text,
                x: 80,
                y: 80,
                width: CanvasPlacementSizing.defaultSize.width,
                height: CanvasPlacementSizing.defaultSize.height,
                style: .default
            )
            let result = execute(
                toolName: "canvas_create_sticky_note",
                workspaceID: workspace.id,
                arguments: arguments,
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Created a new note." : result.message)
        case .duplicate:
            let objects = targetObjects(chat: chat, workspace: workspace)
            guard !objects.isEmpty else {
                finish(assistantMessage, content: "Attach or select canvas cards before asking me to duplicate them.")
                return
            }
            let arguments = WorkspaceDuplicateObjectsArguments(
                objectIDs: objects.map(\.id),
                offsetX: 28,
                offsetY: 28
            )
            let result = execute(
                toolName: "canvas_duplicate_objects",
                workspaceID: workspace.id,
                arguments: arguments,
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Duplicated \(count(result.changedObjectIDs, singular: "card", plural: "cards"))." : result.message)
        case .move(let deltaX, let deltaY):
            let objects = targetObjects(chat: chat, workspace: workspace)
            guard !objects.isEmpty else {
                finish(assistantMessage, content: "Attach or select canvas cards before asking me to move them.")
                return
            }
            let arguments = WorkspaceMoveObjectsArguments(
                objectIDs: objects.map(\.id),
                deltaX: deltaX,
                deltaY: deltaY
            )
            let result = execute(
                toolName: "canvas_move_objects",
                workspaceID: workspace.id,
                arguments: arguments,
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Moved \(count(result.changedObjectIDs, singular: "card", plural: "cards"))." : result.message)
        case .resize(let delta):
            let objects = targetObjects(chat: chat, workspace: workspace)
            guard !objects.isEmpty else {
                finish(assistantMessage, content: "Attach or select canvas cards before asking me to resize them.")
                return
            }
            let sizes = objects.map { object in
                WorkspaceObjectSize(
                    objectID: object.id,
                    width: max(CanvasPlacementSizing.minimumSize.width, object.width + delta),
                    height: max(CanvasPlacementSizing.minimumSize.height, object.height + delta)
                )
            }
            let result = execute(
                toolName: "canvas_resize_objects",
                workspaceID: workspace.id,
                arguments: WorkspaceResizeObjectsArguments(sizes: sizes),
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Resized \(count(result.changedObjectIDs, singular: "card", plural: "cards"))." : result.message)
        case .delete:
            let objects = targetObjects(chat: chat, workspace: workspace)
            guard !objects.isEmpty else {
                finish(assistantMessage, content: "Attach or select canvas cards before asking me to delete them.")
                return
            }
            let arguments = WorkspaceObjectIDsArguments(objectIDs: objects.map(\.id))
            let result = execute(
                toolName: "canvas_delete_objects",
                workspaceID: workspace.id,
                arguments: arguments,
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.needsConfirmation ? "Deleting cards needs confirmation before I change the canvas." : result.message)
        case .askModel:
            await askModel(userMessage: userMessage, assistantMessage: assistantMessage, chat: chat, workspace: workspace)
        }
    }
}

private extension AIChatCommandRouter {
    enum Command {
        case transform(AITransformSkill)
        case arrangeGrid
        case createNote(String)
        case duplicate
        case move(deltaX: Double, deltaY: Double)
        case resize(delta: Double)
        case delete
        case askModel

        init(message: String) {
            let lower = message.lowercased()
            if let skill = AITransformSkill.matching(message: message) {
                self = .transform(skill)
            } else if lower.contains("arrange") || lower.contains("grid") {
                self = .arrangeGrid
            } else if lower.contains("duplicate") || lower.contains("copy this card") || lower.contains("copy these cards") {
                self = .duplicate
            } else if lower.contains("move") || lower.contains("nudge") || lower.contains("reposition") {
                self = .move(deltaX: Self.horizontalDelta(from: lower), deltaY: Self.verticalDelta(from: lower))
            } else if lower.contains("resize") || lower.contains("bigger") || lower.contains("larger") || lower.contains("smaller") {
                self = .resize(delta: (lower.contains("smaller") || lower.contains("shrink")) ? -48 : 48)
            } else if lower.contains("delete") || lower.contains("remove this card") || lower.contains("remove these cards") {
                self = .delete
            } else if let noteText = Self.noteText(from: message) {
                self = .createNote(noteText)
            } else {
                self = .askModel
            }
        }

        private static func noteText(from message: String) -> String? {
            guard message.range(of: "create", options: .caseInsensitive) != nil
                    || message.range(of: "make", options: .caseInsensitive) != nil
                    || message.range(of: "add", options: .caseInsensitive) != nil else { return nil }
            guard let range = message.range(of: "note", options: .caseInsensitive)
                    ?? message.range(of: "card", options: .caseInsensitive) else { return nil }
            let suffix = message[range.upperBound...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " :.-\n\t"))
            return suffix.isEmpty ? "New note" : suffix
        }

        private static func horizontalDelta(from lower: String) -> Double {
            if lower.contains("left") { return -80 }
            if lower.contains("right") { return 80 }
            if !lower.contains("up") && !lower.contains("down") { return 48 }
            return 0
        }

        private static func verticalDelta(from lower: String) -> Double {
            if lower.contains("up") { return -80 }
            if lower.contains("down") { return 80 }
            return 0
        }
    }

    static func runTransform(
        skillID: String,
        chat: AIChat,
        workspace: Workspace,
        message: ChatMessage,
        in context: ModelContext
    ) -> WorkspaceActionResult {
        let clipIDs = targetClips(chat: chat, workspace: workspace).map(\.id)
        let textObjects = targetObjects(chat: chat, workspace: workspace)
            .filter { $0.clip == nil && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var lastResult: WorkspaceActionResult?
        if !clipIDs.isEmpty {
            let arguments = WorkspaceClipApplyTransformArguments(clipIDs: clipIDs, skillID: skillID)
            lastResult = execute(
                toolName: "clip_apply_transform",
                workspaceID: workspace.id,
                arguments: arguments,
                message: message,
                in: context
            )
        }

        for object in textObjects {
            guard let transformed = TextTransformFallbacks.text(for: skillID, input: object.text) else { continue }
            let arguments = WorkspaceUpdateObjectTextArguments(objectID: object.id, text: transformed)
            lastResult = execute(
                toolName: "canvas_update_object_text",
                workspaceID: workspace.id,
                arguments: arguments,
                message: message,
                in: context
            )
        }

        return lastResult ?? .failure("Attach a text card or clip note first.")
    }

    static func execute<T: Encodable>(
        toolName: String,
        workspaceID: UUID,
        arguments: T,
        message: ChatMessage,
        in context: ModelContext
    ) -> WorkspaceActionResult {
        do {
            let call = try AIWorkspaceToolCall(toolName: toolName, workspaceID: workspaceID, arguments: arguments)
            return AIWorkspaceToolExecutor.execute(call, message: message, in: context)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    static func targetObjects(chat: AIChat, workspace: Workspace) -> [CanvasObject] {
        let attached = chat.sortedMessages
            .flatMap(\.sortedAttachments)
            .compactMap(\.canvasObject)
            .filter(\.isCanvasContent)
        if !attached.isEmpty {
            return unique(attached)
        }
        return workspace.canvasObjects.filter(\.isCanvasContent)
    }

    static func targetClips(chat: AIChat, workspace: Workspace) -> [Clip] {
        let attachedClips = targetObjects(chat: chat, workspace: workspace).compactMap(\.clip)
        if !attachedClips.isEmpty {
            return unique(attachedClips).filter { $0.deletedAt == nil }
        }
        return unique(workspace.canvasObjects.compactMap(\.clip)).filter { $0.deletedAt == nil }
    }

    static func summary(for chat: AIChat, workspace: Workspace) -> String {
        let objects = targetObjects(chat: chat, workspace: workspace)
        guard !objects.isEmpty else {
            return "This workspace has no visible canvas cards yet. I can create notes, arrange cards, and transform attached text cards."
        }

        let previews = objects.prefix(4).map { object in
            object.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        let countText = count(objects.map(\.id), singular: "visible card", plural: "visible cards")
        guard !previews.isEmpty else {
            return "I found \(countText). I can arrange them or transform any attached text cards."
        }
        return "I found \(countText): \(previews.joined(separator: " | "))"
    }

    static func askModel(
        userMessage: ChatMessage,
        assistantMessage: ChatMessage,
        chat: AIChat,
        workspace: Workspace
    ) async {
        do {
            let fallbackModel = AIModelPresetService.preset(for: chat.mode).model
            let model = OpenAIConfiguration.model(default: fallbackModel)
            let input = AIChatPromptBuilder.input(for: userMessage, chat: chat, workspace: workspace)
            let result = try await OpenAIResponsesClient().response(
                model: model,
                instructions: AIChatPromptBuilder.instructions,
                input: input,
                previousResponseID: chat.lastResponseID
            )
            assistantMessage.openAIResponseID = result.id
            chat.lastResponseID = result.id
            finish(assistantMessage, content: result.text)
        } catch {
            fail(assistantMessage, content: error.localizedDescription)
        }
    }

    static func finish(_ message: ChatMessage, content: String) {
        message.content = content
        message.status = .completed
        message.chat?.updatedAt = Date()
    }

    static func fail(_ message: ChatMessage, content: String) {
        message.content = content
        message.errorMessage = content
        message.status = .failed
        message.chat?.updatedAt = Date()
    }

    static func count<T>(_ values: [T], singular: String, plural: String) -> String {
        "\(values.count) \(values.count == 1 ? singular : plural)"
    }

    static func unique(_ objects: [CanvasObject]) -> [CanvasObject] {
        var seen = Set<UUID>()
        return objects.filter { seen.insert($0.id).inserted }
    }

    static func unique(_ clips: [Clip]) -> [Clip] {
        var seen = Set<UUID>()
        return clips.filter { seen.insert($0.id).inserted }
    }
}
