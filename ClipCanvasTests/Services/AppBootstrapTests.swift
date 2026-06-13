import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct AppBootstrapTests {
    @Test func seedsBuiltInTagsOnce() throws {
        let context = try ModelContextFactory.makeCoreContext()

        AppBootstrap.ensureActiveWorkspace(in: context)
        AppBootstrap.ensureActiveWorkspace(in: context)

        let tags = try context.fetch(FetchDescriptor<ClipTag>())
        #expect(tags.count == ClipTag.builtInDefinitions.count)
    }

    @Test func runsPlacementMigration() throws {
        let context = try ModelContextFactory.makeCoreContext()
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
}
