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
        case .plan(let plan):
            let result = run(plan: plan, chat: chat, fallbackWorkspace: workspace, message: assistantMessage, in: context)
            finish(assistantMessage, content: result)
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
        case .group:
            let objects = targetObjects(chat: chat, workspace: workspace)
            guard objects.count > 1 else {
                finish(assistantMessage, content: "Attach or select at least two cards before asking me to group them.")
                return
            }
            let result = execute(
                toolName: "canvas_group_objects",
                workspaceID: workspace.id,
                arguments: WorkspaceObjectIDsArguments(objectIDs: objects.map(\.id)),
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Grouped \(count(result.changedObjectIDs, singular: "card", plural: "cards"))." : result.message)
        case .ungroup:
            let objects = targetObjects(chat: chat, workspace: workspace)
            guard !objects.isEmpty else {
                finish(assistantMessage, content: "Attach or select cards before asking me to ungroup them.")
                return
            }
            let result = execute(
                toolName: "canvas_ungroup_objects",
                workspaceID: workspace.id,
                arguments: WorkspaceObjectIDsArguments(objectIDs: objects.map(\.id)),
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Ungrouped \(count(result.changedObjectIDs, singular: "card", plural: "cards"))." : result.message)
        case .addTags(let tagNames):
            let clips = targetClips(chat: chat, workspace: workspace)
            guard !clips.isEmpty else {
                finish(assistantMessage, content: "Attach or select clipboard-backed cards before asking me to tag them.")
                return
            }
            let names = tagNames.isEmpty ? suggestedTagNames(for: clips) : tagNames
            let result = execute(
                toolName: "clip_add_tags",
                workspaceID: workspace.id,
                arguments: WorkspaceClipTagsArguments(clipIDs: clips.map(\.id), tagIDs: [], tagNames: names),
                message: assistantMessage,
                in: context
            )
            finish(assistantMessage, content: result.success ? "Added \(count(names, singular: "tag", plural: "tags"))." : result.message)
        case .format(let kind):
            let result = runFormat(kind, chat: chat, workspace: workspace, message: assistantMessage, in: context)
            finish(assistantMessage, content: result.success ? "Formatted \(count(result.changedObjectIDs + result.changedClipIDs, singular: "item", plural: "items"))." : result.message)
        case .markSensitive:
            let result = runSensitivity(markingSensitive: true, chat: chat, workspace: workspace, message: assistantMessage, in: context)
            finish(assistantMessage, content: result.success ? "Marked sensitive text in \(count(result.changedObjectIDs + result.changedClipIDs, singular: "item", plural: "items"))." : result.message)
        case .unmarkSensitive:
            let result = runSensitivity(markingSensitive: false, chat: chat, workspace: workspace, message: assistantMessage, in: context)
            finish(assistantMessage, content: result.success ? "Removed sensitive markdown from \(count(result.changedObjectIDs + result.changedClipIDs, singular: "item", plural: "items"))." : result.message)
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
    struct CommandPlan {
        var workspaceName: String?
        var noteTexts: [String]
        var shouldArrange: Bool

        var hasWork: Bool {
            workspaceName != nil || !noteTexts.isEmpty || shouldArrange
        }

        init?(message: String) {
            let lower = message.lowercased()
            let asksForWorkspace = lower.contains("new workspace") || lower.contains("create workspace") || lower.contains("make workspace")
            let mentionsNote = lower.contains("note") || lower.contains("card")
            let asksToCreateNote = mentionsNote && (lower.contains("create") || lower.contains("make") || lower.contains("add"))
            let asksForMultipleNotes = lower.contains("new note next to") || lower.contains("another note") || lower.contains("second note")
            let asksForArrange = lower.contains("arrange") || lower.contains("grid")

            guard asksForWorkspace || asksToCreateNote && (asksForMultipleNotes || asksForArrange) else { return nil }

            workspaceName = asksForWorkspace ? Self.workspaceName(from: message) : nil
            shouldArrange = asksForArrange
            noteTexts = []

            if asksToCreateNote {
                if lower.contains("everything you can do") || lower.contains("what you can do") {
                    noteTexts.append(Self.capabilitiesNote)
                } else if let noteText = Command.noteText(from: message) {
                    noteTexts.append(noteText)
                } else {
                    noteTexts.append("New note")
                }
            }
            if asksForMultipleNotes {
                noteTexts.append("New note")
            }
        }

        private static func workspaceName(from message: String) -> String {
            let patterns = [
                #"(?i)name\s+the\s+workspace\s+(.+?)(?:,|\.|\n|;|\s+in\s+|\s+then\s+|$)"#,
                #"(?i)(?:new|create|make)\s+workspace\s+(?:called|named)?\s*(.+?)(?:,|\.|\n|;|\s+in\s+|\s+then\s+|$)"#
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let nsRange = NSRange(message.startIndex..., in: message)
                guard let match = regex.firstMatch(in: message, range: nsRange),
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: message) else { continue }
                let name = String(message[range])
                    .trimmingCharacters(in: CharacterSet(charactersIn: " :.-\n\t"))
                if !name.isEmpty { return WorkspaceNamePolicy.normalized(name) }
            }
            return WorkspaceNamePolicy.normalized("New Workspace")
        }

        private static let capabilitiesNote = """
        # What I can do
        - Create and arrange notes on the canvas
        - Duplicate, move, resize, and delete cards
        - Clean up, summarize, rewrite, title, and extract action items from text
        - Add tags and update clipboard-backed text
        - Link to workspaces, cards, clipboard items, and chats
        """
    }

    enum Command {
        case plan(CommandPlan)
        case arrangeGrid
        case createNote(String)
        case duplicate
        case move(deltaX: Double, deltaY: Double)
        case resize(delta: Double)
        case group
        case ungroup
        case addTags([String])
        case format(NoteTextCommandKind)
        case markSensitive
        case unmarkSensitive
        case delete
        case askModel

        init(message: String) {
            let lower = message.lowercased()
            if let plan = CommandPlan(message: message), plan.hasWork {
                self = .plan(plan)
            } else if lower.contains("arrange") || lower.contains("grid") {
                self = .arrangeGrid
            } else if lower.contains("duplicate") || lower.contains("copy this card") || lower.contains("copy these cards") {
                self = .duplicate
            } else if lower.contains("move") || lower.contains("nudge") || lower.contains("reposition") {
                self = .move(deltaX: Self.horizontalDelta(from: lower), deltaY: Self.verticalDelta(from: lower))
            } else if lower.contains("resize") || lower.contains("bigger") || lower.contains("larger") || lower.contains("smaller") {
                self = .resize(delta: (lower.contains("smaller") || lower.contains("shrink")) ? -48 : 48)
            } else if lower.contains("ungroup") {
                self = .ungroup
            } else if lower.contains("group") {
                self = .group
            } else if lower.contains("remove sensitive") || lower.contains("mark insensitive") || lower.contains("unmark sensitive") {
                self = .unmarkSensitive
            } else if lower.contains("mark") && (lower.contains("sensitive") || lower.contains("private") || lower.contains("password")) {
                self = .markSensitive
            } else if let format = Self.formatCommand(from: lower) {
                self = .format(format)
            } else if lower.contains("suggest tags") || lower.contains("add tag") || lower.contains("tag ") || lower.contains("tags") {
                self = .addTags(Self.tagNames(from: message))
            } else if lower.contains("delete") || lower.contains("remove this card") || lower.contains("remove these cards") {
                self = .delete
            } else if let noteText = Self.noteText(from: message) {
                self = .createNote(noteText)
            } else {
                self = .askModel
            }
        }

        fileprivate static func noteText(from message: String) -> String? {
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

        private static func formatCommand(from lower: String) -> NoteTextCommandKind? {
            guard lower.contains("format")
                    || lower.contains("make")
                    || lower.contains("turn")
                    || lower.contains("highlight")
                    || lower.contains("bold")
                    || lower.contains("italic")
                    || lower.contains("underline")
                    || lower.contains("list") else {
                return nil
            }
            if lower.contains("title") { return .blockStyle(.title) }
            if lower.contains("subheading") || lower.contains("subhead") { return .blockStyle(.subheading) }
            if lower.contains("heading") || lower.contains("header") { return .blockStyle(.heading) }
            if lower.contains("monostyled") || lower.contains("monospace") || lower.contains("code style") { return .blockStyle(.monostyled) }
            if lower.contains("body") { return .blockStyle(.body) }
            if lower.contains("checklist") || lower.contains("check list") { return .list(.checklist) }
            if lower.contains("numbered list") || lower.contains("number list") { return .list(.numbered) }
            if lower.contains("dashed list") || lower.contains("dash list") { return .list(.dashed) }
            if lower.contains("bullet") || lower.contains("list") { return .list(.bullet) }
            if lower.contains("quote") { return .quote }
            if lower.contains("highlight") { return .highlight(highlightColor(from: lower)) }
            if lower.contains("strikethrough") || lower.contains("strike") { return .strikethrough }
            if lower.contains("underline") { return .underline }
            if lower.contains("italic") { return .italic }
            if lower.contains("bold") { return .bold }
            return nil
        }

        private static func highlightColor(from lower: String) -> NoteHighlightColor {
            NoteHighlightColor.allCases.first { lower.contains($0.rawValue) } ?? .yellow
        }

        private static func tagNames(from message: String) -> [String] {
            let patterns = [
                #"(?i)(?:add\s+tags?|tag(?:\s+these|\s+this)?(?:\s+as)?)\s+(.+?)(?:\.|\n|$)"#,
                #"(?i)tags?\s*:\s*(.+?)(?:\.|\n|$)"#
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let nsRange = NSRange(message.startIndex..., in: message)
                guard let match = regex.firstMatch(in: message, range: nsRange),
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: message) else { continue }
                let names = String(message[range])
                    .components(separatedBy: CharacterSet(charactersIn: ",;"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("suggest") }
                if !names.isEmpty { return names }
            }
            return []
        }
    }

    static func run(
        plan: CommandPlan,
        chat: AIChat,
        fallbackWorkspace: Workspace,
        message: ChatMessage,
        in context: ModelContext
    ) -> String {
        let workspace = plan.workspaceName.map { name in
            createWorkspace(named: name, chat: chat, context: context)
        } ?? fallbackWorkspace

        var changedObjectIDs: [UUID] = []
        for (index, noteText) in plan.noteTexts.enumerated() {
            let arguments = WorkspaceCreateStickyNoteArguments(
                text: noteText,
                x: 80 + Double(index) * (CanvasPlacementSizing.defaultSize.width + 28),
                y: 80,
                width: CanvasPlacementSizing.defaultSize.width,
                height: CanvasPlacementSizing.defaultSize.height,
                style: .default
            )
            let result = execute(
                toolName: "canvas_create_sticky_note",
                workspaceID: workspace.id,
                arguments: arguments,
                message: message,
                in: context
            )
            changedObjectIDs.append(contentsOf: result.changedObjectIDs)
        }

        if plan.shouldArrange {
            let objectIDs = changedObjectIDs.isEmpty
                ? workspace.canvasObjects.filter(\.isCanvasContent).map(\.id)
                : changedObjectIDs
            if !objectIDs.isEmpty {
                let columns = max(1, Int(ceil(sqrt(Double(objectIDs.count)))))
                _ = execute(
                    toolName: "canvas_arrange_grid",
                    workspaceID: workspace.id,
                    arguments: WorkspaceArrangeGridArguments(
                        objectIDs: objectIDs,
                        originX: 0,
                        originY: 0,
                        columnCount: columns,
                        horizontalSpacing: 22,
                        verticalSpacing: 22
                    ),
                    message: message,
                    in: context
                )
            }
        }

        var parts: [String] = []
        if let workspaceName = plan.workspaceName {
            parts.append("created workspace \(workspaceName)")
        }
        if !plan.noteTexts.isEmpty {
            parts.append("added \(count(plan.noteTexts, singular: "note", plural: "notes"))")
        }
        if plan.shouldArrange {
            parts.append("arranged \(changedObjectIDs.isEmpty ? "the cards" : "them")")
        }
        return parts.isEmpty ? summary(for: chat, workspace: workspace) : parts.joined(separator: ", ").capitalizedFirst + "."
    }

    static func createWorkspace(named name: String, chat: AIChat, context: ModelContext) -> Workspace {
        let workspaces = (try? context.fetch(FetchDescriptor<Workspace>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        let workspace = WorkspaceActionService.create(in: context, existing: workspaces, name: name)
        chat.workspace = workspace
        workspace.chats.append(chat)
        return workspace
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

    static func runFormat(
        _ kind: NoteTextCommandKind,
        chat: AIChat,
        workspace: Workspace,
        message: ChatMessage,
        in context: ModelContext
    ) -> WorkspaceActionResult {
        let objects = targetObjects(chat: chat, workspace: workspace)
            .filter { $0.clip?.type != .image }
        guard !objects.isEmpty else { return .failure("Attach or select text cards before asking me to format them.") }

        var changedObjectIDs: [UUID] = []
        var changedClipIDs: [UUID] = []
        var lastMessage = "Formatted text"

        for object in objects {
            let source = object.clip?.content ?? object.text
            guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let range = NSRange(source.startIndex..., in: source)
            let formatted = NoteTextFormattingEngine.apply(kind, to: source, selectedRange: range).text

            if let clip = object.clip {
                let result = execute(
                    toolName: "clip_update_content",
                    workspaceID: workspace.id,
                    arguments: WorkspaceClipUpdateContentArguments(clipID: clip.id, content: formatted),
                    message: message,
                    in: context
                )
                lastMessage = result.message
                changedClipIDs.append(contentsOf: result.changedClipIDs)
            } else {
                let result = execute(
                    toolName: "canvas_update_object_text",
                    workspaceID: workspace.id,
                    arguments: WorkspaceUpdateObjectTextArguments(objectID: object.id, text: formatted),
                    message: message,
                    in: context
                )
                lastMessage = result.message
                changedObjectIDs.append(contentsOf: result.changedObjectIDs)
            }
        }

        guard !changedObjectIDs.isEmpty || !changedClipIDs.isEmpty else {
            return .failure(lastMessage)
        }
        return .success(lastMessage, changedObjectIDs: changedObjectIDs, changedClipIDs: changedClipIDs)
    }

    static func runSensitivity(
        markingSensitive: Bool,
        chat: AIChat,
        workspace: Workspace,
        message: ChatMessage,
        in context: ModelContext
    ) -> WorkspaceActionResult {
        let objects = targetObjects(chat: chat, workspace: workspace)
            .filter { $0.clip?.type != .image }
        guard !objects.isEmpty else { return .failure("Attach or select text cards before changing sensitivity.") }

        var changedObjectIDs: [UUID] = []
        var changedClipIDs: [UUID] = []
        var lastMessage = markingSensitive ? "Marked sensitive text" : "Removed sensitive markdown"

        for object in objects {
            let source = object.clip?.content ?? object.text
            let updated = markingSensitive
                ? ClipClassificationService.markSensitiveMarkdown(in: source)
                : removeSensitiveMarkdown(from: source)
            guard updated != source else { continue }

            if let clip = object.clip {
                let result = execute(
                    toolName: "clip_update_content",
                    workspaceID: workspace.id,
                    arguments: WorkspaceClipUpdateContentArguments(clipID: clip.id, content: updated),
                    message: message,
                    in: context
                )
                lastMessage = result.message
                changedClipIDs.append(contentsOf: result.changedClipIDs)
            } else {
                let result = execute(
                    toolName: "canvas_update_object_text",
                    workspaceID: workspace.id,
                    arguments: WorkspaceUpdateObjectTextArguments(objectID: object.id, text: updated),
                    message: message,
                    in: context
                )
                lastMessage = result.message
                changedObjectIDs.append(contentsOf: result.changedObjectIDs)
            }
        }

        guard !changedObjectIDs.isEmpty || !changedClipIDs.isEmpty else {
            return .failure(markingSensitive ? "I could not confidently find sensitive text to mark." : "There was no sensitive markdown to remove.")
        }
        return .success(lastMessage, changedObjectIDs: changedObjectIDs, changedClipIDs: changedClipIDs)
    }

    static func suggestedTagNames(for clips: [Clip]) -> [String] {
        let text = clips.map(\.content).joined(separator: "\n")
        return TextTransformFallbacks.suggestedTags(for: text)
    }

    static func removeSensitiveMarkdown(from text: String) -> String {
        let regex = try? NSRegularExpression(pattern: #"\|\|(.+?)\|\|"#)
        let range = NSRange(text.startIndex..., in: text)
        return regex?.stringByReplacingMatches(in: text, range: range, withTemplate: "$1") ?? text
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

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
