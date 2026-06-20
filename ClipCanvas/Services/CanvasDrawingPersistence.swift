import Foundation
import PencilKit
import SwiftData

enum CanvasDrawingPersistence {
    static func drawing(in workspace: Workspace) -> PKDrawing {
        guard let data = drawingObject(in: workspace)?.drawingData,
              let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    static func persist(_ drawing: PKDrawing, in workspace: Workspace, context: ModelContext) {
        if drawing.bounds.isEmpty {
            if let existing = drawingObject(in: workspace) {
                workspace.canvasObjects.removeAll { $0.id == existing.id }
                context.delete(existing)
                workspace.updatedAt = Date()
            }
            return
        }

        let object = drawingObject(in: workspace) ?? makeDrawingObject(in: workspace, context: context)
        object.drawingData = drawing.dataRepresentation()
        object.frame = drawing.bounds
        object.markUpdated()
        workspace.updatedAt = Date()
    }

    static func drawingObject(in workspace: Workspace) -> CanvasObject? {
        workspace.canvasObjects.first { $0.kind == .drawing && $0.deletedAt == nil }
    }

    private static func makeDrawingObject(in workspace: Workspace, context: ModelContext) -> CanvasObject {
        let object = CanvasObject(
            kind: .drawing,
            workspace: workspace,
            x: 0,
            y: 0,
            width: 1,
            height: 1
        )
        object.zIndex = -1
        workspace.canvasObjects.append(object)
        context.insert(object)
        return object
    }
}
