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

nonisolated struct WorkspaceCreateConnectorArguments: Codable, Equatable {
    var connector: CanvasConnector
}

nonisolated struct WorkspaceUpdateConnectorArguments: Codable, Equatable {
    var objectID: UUID
    var connector: CanvasConnector
}

nonisolated struct WorkspaceArrangeGridArguments: Codable, Equatable {
    var objectIDs: [UUID]
    var originX: Double
    var originY: Double
    var columnCount: Int
    var horizontalSpacing: Double
    var verticalSpacing: Double
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
            case .canvasCreateConnector:
                return try createConnector(request, workspace: workspace, context: context)
            case .canvasUpdateConnector:
                return try updateConnector(request, workspace: workspace)
            case .canvasGroupObjects:
                return try groupObjects(request, workspace: workspace)
            case .canvasUngroupObjects:
                return try ungroupObjects(request, workspace: workspace)
            case .canvasArrangeGrid:
                return try arrangeGrid(request, workspace: workspace)
            case .canvasFitViewToContent:
                return .success("Fit view to content")
            case .clipApplyTransform, .clipUpdateContent, .clipAddTags, .clipRemoveTags, .chatAttachObjects:
                return .failure("Action handler not implemented yet")
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

    static func createConnector(
        _ request: WorkspaceActionRequest,
        workspace: Workspace,
        context: ModelContext
    ) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceCreateConnectorArguments.self, from: request)
        let object = CanvasObject(
            kind: .connector,
            workspace: workspace,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            connector: arguments.connector
        )
        object.zIndex = nextZIndex(in: workspace)
        context.insert(object)
        workspace.canvasObjects.append(object)
        return .success("Created connector", changedObjectIDs: [object.id])
    }

    static func updateConnector(_ request: WorkspaceActionRequest, workspace: Workspace) throws -> WorkspaceActionResult {
        let arguments = try decode(WorkspaceUpdateConnectorArguments.self, from: request)
        guard let object = object(id: arguments.objectID, in: workspace) else {
            return .failure("Object not found")
        }
        object.connector = arguments.connector
        object.kind = .connector
        object.markUpdated()
        return .success("Updated connector", changedObjectIDs: [object.id])
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
        let columns = max(1, arguments.columnCount)
        var changedIDs: [UUID] = []
        var y = arguments.originY

        for rowStart in stride(from: 0, to: selected.count, by: columns) {
            let row = Array(selected[rowStart..<min(rowStart + columns, selected.count)])
            var x = arguments.originX
            let rowHeight = row.map(\.height).max() ?? 0

            for object in row {
                object.x = x
                object.y = y
                object.markUpdated()
                changedIDs.append(object.id)
                x += object.width + arguments.horizontalSpacing
            }

            y += rowHeight + arguments.verticalSpacing
        }

        return .success("Arranged objects", changedObjectIDs: changedIDs)
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

    static func object(id: UUID, in workspace: Workspace) -> CanvasObject? {
        workspace.canvasObjects.first { $0.id == id && $0.deletedAt == nil }
    }

    static func objects(ids: [UUID], in workspace: Workspace) -> [CanvasObject] {
        ids.compactMap { object(id: $0, in: workspace) }
    }

    static func nextZIndex(in workspace: Workspace) -> Double {
        (workspace.canvasObjects.map(\.zIndex).max() ?? 0) + 1
    }
}
