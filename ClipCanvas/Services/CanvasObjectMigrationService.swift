import Foundation
import SwiftData

enum CanvasObjectMigrationService {
    static func migratePlacements(in context: ModelContext) {
        let existingObjects = (try? context.fetch(FetchDescriptor<CanvasObject>())) ?? []
        var migratedPlacementIDs = Set(existingObjects.compactMap(\.sourcePlacementID))
        let placements = (try? context.fetch(FetchDescriptor<CanvasPlacement>())) ?? []

        for placement in placements {
            guard !migratedPlacementIDs.contains(placement.id) else { continue }
            guard let workspace = placement.workspace, workspace.deletedAt == nil else { continue }
            guard let clip = placement.clip, clip.deletedAt == nil else { continue }

            let object = CanvasObject(
                kind: .clipNote,
                workspace: workspace,
                clip: clip,
                x: placement.x,
                y: placement.y,
                width: placement.width,
                height: placement.height
            )
            object.sourcePlacementID = placement.id
            object.createdAt = placement.createdAt
            object.updatedAt = placement.createdAt
            object.zIndex = Double(workspace.canvasObjects.count)

            context.insert(object)
            workspace.canvasObjects.append(object)
            migratedPlacementIDs.insert(placement.id)
        }
    }
}
