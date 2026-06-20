import CoreGraphics
import Foundation
import PencilKit
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct CanvasDrawingPersistenceTests {
    @Test func persistsAndReloadsWorkspaceDrawing() throws {
        let context = try ModelContextFactory.makeCoreContext()
        let workspace = Workspace(name: "Board")
        context.insert(workspace)

        let drawing = Self.sampleDrawing()
        CanvasDrawingPersistence.persist(drawing, in: workspace, context: context)

        let object = try #require(workspace.canvasObjects.first)
        #expect(object.kind == .drawing)
        #expect(object.drawingData != nil)
        #expect(!CanvasDrawingPersistence.drawing(in: workspace).bounds.isEmpty)
    }

    @Test func emptyDrawingRemovesBackingObject() throws {
        let context = try ModelContextFactory.makeCoreContext()
        let workspace = Workspace(name: "Board")
        context.insert(workspace)

        CanvasDrawingPersistence.persist(Self.sampleDrawing(), in: workspace, context: context)
        #expect(workspace.canvasObjects.contains { $0.kind == .drawing })

        CanvasDrawingPersistence.persist(PKDrawing(), in: workspace, context: context)

        #expect(!workspace.canvasObjects.contains { $0.kind == .drawing })
    }

    private static func sampleDrawing() -> PKDrawing {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 10, y: 10),
                timeOffset: 0,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            ),
            PKStrokePoint(
                location: CGPoint(x: 80, y: 52),
                timeOffset: 0.1,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        ]
        let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        let stroke = PKStroke(ink: PKInk(.pen, color: PlatformColor.black), path: path)
        return PKDrawing(strokes: [stroke])
    }
}
