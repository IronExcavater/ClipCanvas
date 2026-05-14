import CoreGraphics
import Foundation
import SwiftData

nonisolated struct WorkspaceActionRequest: Codable, Identifiable {
    var id: UUID = UUID()
    var name: WorkspaceActionName
    var workspaceID: UUID
    var argumentsData: Data
    var source: WorkspaceActionSource

    init(
        id: UUID = UUID(),
        name: WorkspaceActionName,
        workspaceID: UUID,
        argumentsData: Data,
        source: WorkspaceActionSource
    ) {
        self.id = id
        self.name = name
        self.workspaceID = workspaceID
        self.argumentsData = argumentsData
        self.source = source
    }
}

nonisolated struct WorkspaceActionResult: Codable, Equatable {
    var success: Bool
    var message: String
    var changedObjectIDs: [UUID]
    var changedClipIDs: [UUID]
    var needsConfirmation: Bool

    static func success(
        _ message: String,
        changedObjectIDs: [UUID] = [],
        changedClipIDs: [UUID] = []
    ) -> WorkspaceActionResult {
        WorkspaceActionResult(
            success: true,
            message: message,
            changedObjectIDs: changedObjectIDs,
            changedClipIDs: changedClipIDs,
            needsConfirmation: false
        )
    }

    static func failure(_ message: String, needsConfirmation: Bool = false) -> WorkspaceActionResult {
        WorkspaceActionResult(
            success: false,
            message: message,
            changedObjectIDs: [],
            changedClipIDs: [],
            needsConfirmation: needsConfirmation
        )
    }
}

nonisolated struct EmptyWorkspaceActionArguments: Codable, Equatable {}

nonisolated struct WorkspaceCreateStickyNoteArguments: Codable, Equatable {
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var style: CanvasObjectStyle
}

nonisolated struct WorkspaceCreateClipNoteArguments: Codable, Equatable {
    var clipID: UUID
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

nonisolated struct WorkspaceUpdateObjectTextArguments: Codable, Equatable {
    var objectID: UUID
    var text: String
}

nonisolated struct WorkspaceMoveObjectsArguments: Codable, Equatable {
    var objectIDs: [UUID]
    var deltaX: Double
    var deltaY: Double
}

nonisolated struct WorkspaceObjectSize: Codable, Equatable {
    var objectID: UUID
    var width: Double
    var height: Double
}

nonisolated struct WorkspaceResizeObjectsArguments: Codable, Equatable {
    var sizes: [WorkspaceObjectSize]
}

nonisolated struct WorkspaceObjectIDsArguments: Codable, Equatable {
    var objectIDs: [UUID]
}

nonisolated struct WorkspaceDuplicateObjectsArguments: Codable, Equatable {
    var objectIDs: [UUID]
    var offsetX: Double
    var offsetY: Double
}

nonisolated struct WorkspaceArrangeGridArguments: Codable, Equatable {
    var objectIDs: [UUID]
    var originX: Double
    var originY: Double
    var columnCount: Int
    var horizontalSpacing: Double
    var verticalSpacing: Double
}

nonisolated struct WorkspaceClipApplyTransformArguments: Codable, Equatable {
    var clipIDs: [UUID]
    var skillID: String
}

nonisolated struct WorkspaceClipUpdateContentArguments: Codable, Equatable {
    var clipID: UUID
    var content: String
}

nonisolated struct WorkspaceClipTagsArguments: Codable, Equatable {
    var clipIDs: [UUID]
    var tagIDs: [UUID]
    var tagNames: [String]
}

nonisolated struct WorkspaceChatAttachObjectsArguments: Codable, Equatable {
    var chatID: UUID
    var objectIDs: [UUID]
    var messageContent: String?
}

enum WorkspaceActionRegistry {
    static func perform(
        _ request: WorkspaceActionRequest,
        in context: ModelContext,
        confirmed: Bool = false
    ) -> WorkspaceActionResult {
        let validation = WorkspaceActionPermissionService.validate(name: request.name, source: request.source)
        guard validation.isAllowed else {
            return .failure(validation.message)
        }
        if validation.requiresConfirmation && !confirmed {
            return .failure("Confirmation required", needsConfirmation: true)
        }
        guard let workspace = fetchWorkspace(id: request.workspaceID, in: context) else {
            return .failure("Workspace not found")
        }

        do {
            switch request.name {
            case .canvasCreateStickyNote:
                return try createStickyNote(request, workspace: workspace, context: context)
            case .canvasCreateClipNote:
                return try createClipNote(request, workspace: workspace, context: context)
            case .canvasUpdateObjectText:
                return try updateObjectText(request, workspace: workspace)
            case .canvasMoveObjects:
                return try moveObjects(request, workspace: workspace)
            case .canvasResizeObjects:
                return try resizeObjects(request, workspace: workspace)
            case .canvasDeleteObjects:
                return try deleteObjects(request, workspace: workspace, context: context)
            case .canvasDuplicateObjects:
                return try duplicateObjects(request, workspace: workspace, context: context)
            case .canvasGroupObjects:
                return try groupObjects(request, workspace: workspace)
            case .canvasUngroupObjects:
                return try ungroupObjects(request, workspace: workspace)
            case .canvasArrangeGrid:
                return try arrangeGrid(request, workspace: workspace)
            case .canvasFitViewToContent:
                return .success("Fit view to content")
            case .clipApplyTransform:
                return try applyClipTransform(request, context: context)
            case .clipUpdateContent:
                return try updateClipContent(request, context: context)
            case .clipAddTags:
                return try addClipTags(request, context: context)
            case .clipRemoveTags:
                return try removeClipTags(request, context: context)
            case .chatAttachObjects:
                return try attachObjectsToChat(request, workspace: workspace, context: context)
            case .workspaceCreate, .workspaceDelete, .workspaceRename, .workspaceActivate:
                return .failure("Workspace management is not available through shared workspace actions.")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

private extension WorkspaceActionRegistry {
    static func createStickyNote(
        _ request: WorkspaceActionRequest,
        workspace: Workspace,
        context: ModelContext
    ) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceCreateStickyNoteArguments.self, from: request)
        let object = CanvasObject(
            kind: .stickyNote,
            workspace: workspace,
            x: arguments.x,
            y: arguments.y,
            width: arguments.width,
            height: arguments.height,
            text: arguments.text,
            style: arguments.style
        )
        object.zIndex = nextZIndex(in: workspace)
        context.insert(object)
        workspace.canvasObjects.append(object)
        return .success("Created sticky note", changedObjectIDs: [object.id])
    }

    static func createClipNote(
        _ request: WorkspaceActionRequest,
        workspace: Workspace,
        context: ModelContext
    ) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceCreateClipNoteArguments.self, from: request)
        guard let clip = fetchClip(id: arguments.clipID, in: context), clip.deletedAt == nil else {
            return .failure("Clip not found")
        }
        let object = CanvasObject(
            kind: .clipNote,
            workspace: workspace,
            clip: clip,
            x: arguments.x,
            y: arguments.y,
            width: arguments.width,
            height: arguments.height
        )
        object.zIndex = nextZIndex(in: workspace)
        context.insert(object)
        workspace.canvasObjects.append(object)
        return .success("Created clip note", changedObjectIDs: [object.id])
    }

    static func updateObjectText(_ request: WorkspaceActionRequest, workspace: Workspace) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceUpdateObjectTextArguments.self, from: request)
        guard let object = object(id: arguments.objectID, in: workspace) else {
            return .failure("Object not found")
        }
        object.text = arguments.text
        object.markUpdated()
        return .success("Updated object text", changedObjectIDs: [object.id])
    }

    static func moveObjects(_ request: WorkspaceActionRequest, workspace: Workspace) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceMoveObjectsArguments.self, from: request)
        let objects = objects(ids: arguments.objectIDs, in: workspace)
        objects.forEach {
            $0.x += arguments.deltaX
            $0.y += arguments.deltaY
            $0.markUpdated()
        }
        return .success("Moved objects", changedObjectIDs: objects.map(\.id))
    }

    static func resizeObjects(_ request: WorkspaceActionRequest, workspace: Workspace) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceResizeObjectsArguments.self, from: request)
        var changedIDs: [UUID] = []
        for size in arguments.sizes {
            guard let object = object(id: size.objectID, in: workspace) else { continue }
            object.width = max(1, size.width)
            object.height = max(1, size.height)
            object.markUpdated()
            changedIDs.append(object.id)
        }
        return .success("Resized objects", changedObjectIDs: changedIDs)
    }

    static func deleteObjects(
        _ request: WorkspaceActionRequest,
        workspace: Workspace,
        context: ModelContext
    ) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceObjectIDsArguments.self, from: request)
        let selected = objects(ids: arguments.objectIDs, in: workspace)
        selected.forEach { context.delete($0) }
        return .success("Deleted objects", changedObjectIDs: selected.map(\.id))
    }

    static func duplicateObjects(
        _ request: WorkspaceActionRequest,
        workspace: Workspace,
        context: ModelContext
    ) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceDuplicateObjectsArguments.self, from: request)
        let selected = objects(ids: arguments.objectIDs, in: workspace)
        let copies = selected.map { original in
            let copy = CanvasObject(
                kind: original.kind,
                workspace: workspace,
                clip: original.clip,
                x: original.x + arguments.offsetX,
                y: original.y + arguments.offsetY,
                width: original.width,
                height: original.height,
                text: original.text,
                shapeKind: original.shapeKind,
                style: original.style,
                connector: original.connector
            )
            copy.rotation = original.rotation
            copy.groupID = original.groupID
            copy.drawingData = original.drawingData
            copy.zIndex = nextZIndex(in: workspace) + Double(workspace.canvasObjects.count)
            return copy
        }

        copies.forEach {
            context.insert($0)
            workspace.canvasObjects.append($0)
        }
        return .success("Duplicated objects", changedObjectIDs: copies.map(\.id))
    }

    static func groupObjects(_ request: WorkspaceActionRequest, workspace: Workspace) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceObjectIDsArguments.self, from: request)
        let selected = objects(ids: arguments.objectIDs, in: workspace)
        let groupID = UUID()
        selected.forEach {
            $0.groupID = groupID
            $0.markUpdated()
        }
        return .success("Grouped objects", changedObjectIDs: selected.map(\.id))
    }

    static func ungroupObjects(_ request: WorkspaceActionRequest, workspace: Workspace) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceObjectIDsArguments.self, from: request)
        let selected = objects(ids: arguments.objectIDs, in: workspace)
        selected.forEach {
            $0.groupID = nil
            $0.markUpdated()
        }
        return .success("Ungrouped objects", changedObjectIDs: selected.map(\.id))
    }

    static func arrangeGrid(_ request: WorkspaceActionRequest, workspace: Workspace) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceArrangeGridArguments.self, from: request)
        let selected = objects(ids: arguments.objectIDs, in: workspace)
        let objectsByID = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })
        let items = selected.map {
            CanvasGridLayoutItem(id: $0.id, size: CGSize(width: $0.width, height: $0.height))
        }
        let frames = CanvasGridLayout.frames(
            for: items,
            columns: arguments.columnCount,
            origin: CGPoint(x: arguments.originX, y: arguments.originY),
            spacing: CGSize(width: arguments.horizontalSpacing, height: arguments.verticalSpacing)
        )
        var changedIDs: [UUID] = []

        for frame in frames {
            guard let object = objectsByID[frame.id] else { continue }
            object.x = Double(frame.origin.x)
            object.y = Double(frame.origin.y)
            object.markUpdated()
            changedIDs.append(object.id)
        }

        return .success("Arranged objects", changedObjectIDs: changedIDs)
    }

    static func applyClipTransform(_ request: WorkspaceActionRequest, context: ModelContext) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceClipApplyTransformArguments.self, from: request)
        let selected = clips(ids: arguments.clipIDs, in: context)
        guard !selected.isEmpty else { return .failure("Clip not found") }
        guard canReadPrivateContent(selected, source: request.source) else {
            return .failure("Private clips cannot be transformed by automation.")
        }
        guard selected.allSatisfy({ TextTransformFallbacks.text(for: arguments.skillID, input: $0.content) != nil }) else {
            return .failure("Transform not found")
        }

        let now = Date()
        for clip in selected {
            guard let transformed = TextTransformFallbacks.text(for: arguments.skillID, input: clip.content) else { continue }
            update(clip, content: transformed, at: now)
        }
        return .success("Transformed clips", changedClipIDs: selected.map(\.id))
    }

    static func updateClipContent(_ request: WorkspaceActionRequest, context: ModelContext) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceClipUpdateContentArguments.self, from: request)
        guard let clip = fetchClip(id: arguments.clipID, in: context), clip.deletedAt == nil else {
            return .failure("Clip not found")
        }
        guard canReadPrivateContent([clip], source: request.source) else {
            return .failure("Private clips cannot be updated by automation.")
        }
        update(clip, content: arguments.content)
        return .success("Updated clip", changedClipIDs: [clip.id])
    }

    static func addClipTags(_ request: WorkspaceActionRequest, context: ModelContext) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceClipTagsArguments.self, from: request)
        let selected = clips(ids: arguments.clipIDs, in: context)
        guard !selected.isEmpty else { return .failure("Clip not found") }
        let tags = resolveTags(ids: arguments.tagIDs, names: arguments.tagNames, in: context)
        guard !tags.isEmpty else { return .failure("Tag not found") }

        for clip in selected {
            for tag in tags where !clip.tags.contains(where: { $0.id == tag.id }) {
                clip.tags.append(tag)
            }
        }
        return .success("Added tags", changedClipIDs: selected.map(\.id))
    }

    static func removeClipTags(_ request: WorkspaceActionRequest, context: ModelContext) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceClipTagsArguments.self, from: request)
        let selected = clips(ids: arguments.clipIDs, in: context)
        guard !selected.isEmpty else { return .failure("Clip not found") }
        let tagIDs = Set(arguments.tagIDs)
        let tagNames = Set(arguments.tagNames.map { normalizedTagName($0) })

        for clip in selected {
            clip.tags.removeAll { tag in
                tagIDs.contains(tag.id) || tagNames.contains(normalizedTagName(tag.name))
            }
        }
        return .success("Removed tags", changedClipIDs: selected.map(\.id))
    }

    static func attachObjectsToChat(
        _ request: WorkspaceActionRequest,
        workspace: Workspace,
        context: ModelContext
    ) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceChatAttachObjectsArguments.self, from: request)
        guard let chat = fetchChat(id: arguments.chatID, in: context) else {
            return .failure("Chat not found")
        }
        let selected = objects(ids: arguments.objectIDs, in: workspace)
        guard !selected.isEmpty else { return .failure("Object not found") }
        _ = AIChatService.attachObjects(
            selected,
            to: chat,
            in: context,
            messageContent: arguments.messageContent
        )
        return .success("Attached objects", changedObjectIDs: selected.map(\.id))
    }

    static func update(_ clip: Clip, content: String, at date: Date = Date()) {
        let classification = ClipClassificationService.classifySensitivity(content)
        clip.content = content
        clip.type = Clip.detect(content: content, imageData: clip.imageData)
        clip.updateSensitivity(classification.sensitivity, reason: classification.reason, at: date)
        clip.updatedAt = date
    }

    static func decode<T: Decodable>(_ type: T.Type, from request: WorkspaceActionRequest) throws -> T {
        try JSONDecoder().decode(type, from: request.argumentsData)
    }

    static func fetchWorkspace(id: UUID, in context: ModelContext) -> Workspace? {
        let descriptor = FetchDescriptor<Workspace>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    static func fetchClip(id: UUID, in context: ModelContext) -> Clip? {
        let descriptor = FetchDescriptor<Clip>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    static func fetchChat(id: UUID, in context: ModelContext) -> AIChat? {
        let descriptor = FetchDescriptor<AIChat>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    static func clips(ids: [UUID], in context: ModelContext) -> [Clip] {
        let all = (try? context.fetch(FetchDescriptor<Clip>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        let ids = Set(ids)
        return all.filter { ids.contains($0.id) }
    }

    static func object(id: UUID, in workspace: Workspace) -> CanvasObject? {
        workspace.canvasObjects.first { $0.id == id && $0.deletedAt == nil }
    }

    static func objects(ids: [UUID], in workspace: Workspace) -> [CanvasObject] {
        ids.compactMap { object(id: $0, in: workspace) }
    }

    static func nextZIndex(in workspace: Workspace) -> Double {
        (workspace.canvasObjects.map(\.zIndex).max() ?? 0) + 1
    }

    static func canReadPrivateContent(_ clips: [Clip], source: WorkspaceActionSource) -> Bool {
        source == .user || !clips.contains(where: \.isPrivateContent)
    }

    static func resolveTags(ids: [UUID], names: [String], in context: ModelContext) -> [ClipTag] {
        let existing = (try? context.fetch(FetchDescriptor<ClipTag>())) ?? []
        let tagIDs = Set(ids)
        var resolved = existing.filter { tagIDs.contains($0.id) }
        let normalizedExisting = existing.reduce(into: [String: ClipTag]()) { result, tag in
            result[normalizedTagName(tag.name)] = tag
        }
        var nextSortIndex = (existing.map(\.sortIndex).max() ?? 10) + 1

        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = normalizedTagName(trimmed)
            if let tag = normalizedExisting[normalized] {
                if !resolved.contains(where: { $0.id == tag.id }) {
                    resolved.append(tag)
                }
            } else {
                let tag = ClipTag(name: trimmed, colorHex: "#FF9800", isBuiltIn: false, sortIndex: nextSortIndex)
                nextSortIndex += 1
                context.insert(tag)
                resolved.append(tag)
            }
        }

        return resolved
    }

    static func normalizedTagName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
