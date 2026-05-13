import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct CanvasObjectMigrationTests {
    @Test func migratesLivePlacementsIntoClipNoteObjects() throws {
        let context = try makeContext()
        let workspace = Workspace(name: "Migrated")
        let clip = Clip(content: "Source clip", origin: .clipboard)
        let placement = CanvasPlacement(clip: clip, x: 42, y: 84)
        placement.width = 300
        placement.height = 180
        placement.workspace = workspace
        workspace.placements.append(placement)
        context.insert(workspace)
        context.insert(clip)
        context.insert(placement)

        CanvasObjectMigrationService.migratePlacements(in: context)

        let objects = try context.fetch(FetchDescriptor<CanvasObject>())
        #expect(objects.count == 1)
        #expect(objects[0].kind == .clipNote)
        #expect(objects[0].clip?.id == clip.id)
        #expect(objects[0].workspace?.id == workspace.id)
        #expect(objects[0].frame == placement.frame)
        #expect(objects[0].sourcePlacementID == placement.id)
    }

    @Test func migrationIsIdempotent() throws {
        let context = try makeContext()
        let workspace = Workspace(name: "Board")
        let clip = Clip(content: "Existing", origin: .clipboard)
        let placement = CanvasPlacement(clip: clip, x: 10, y: 20)
        placement.workspace = workspace
        workspace.placements.append(placement)
        context.insert(workspace)
        context.insert(clip)
        context.insert(placement)

        CanvasObjectMigrationService.migratePlacements(in: context)
        CanvasObjectMigrationService.migratePlacements(in: context)

        let objects = try context.fetch(FetchDescriptor<CanvasObject>())
        #expect(objects.count == 1)
        #expect(objects[0].sourcePlacementID == placement.id)
    }

    @Test func skipsPlacementsWhoseClipIsSoftDeleted() throws {
        let context = try makeContext()
        let workspace = Workspace(name: "Board")
        let clip = Clip(content: "Deleted", origin: .clipboard)
        clip.softDelete()
        let placement = CanvasPlacement(clip: clip, x: 10, y: 20)
        placement.workspace = workspace
        workspace.placements.append(placement)
        context.insert(workspace)
        context.insert(clip)
        context.insert(placement)

        CanvasObjectMigrationService.migratePlacements(in: context)

        let objects = try context.fetch(FetchDescriptor<CanvasObject>())
        #expect(objects.isEmpty)
    }

    @Test func bootstrapRunsPlacementMigration() throws {
        let context = try makeContext()
        let workspace = Workspace(name: "Board", isActive: true)
        let clip = Clip(content: "Bootstrapped", origin: .clipboard)
        let placement = CanvasPlacement(clip: clip, x: 10, y: 20)
        placement.workspace = workspace
        workspace.placements.append(placement)
        context.insert(workspace)
        context.insert(clip)
        context.insert(placement)

        AppBootstrap.ensureActiveWorkspace(in: context)

        let objects = try context.fetch(FetchDescriptor<CanvasObject>())
        #expect(objects.count == 1)
        #expect(objects[0].sourcePlacementID == placement.id)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}
