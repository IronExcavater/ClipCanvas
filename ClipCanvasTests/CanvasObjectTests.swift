import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct CanvasObjectTests {
    @Test func stickyNoteStoresTextFrameStyleAndWorkspace() {
        let workspace = Workspace(name: "Research")
        let style = CanvasObjectStyle(
            fillHex: "#FFCC66",
            strokeHex: "#D9822B",
            textHex: "#1C1C1E",
            lineWidth: 2,
            fontSize: 17
        )

        let object = CanvasObject(
            kind: .stickyNote,
            workspace: workspace,
            x: 40,
            y: 80,
            width: 260,
            height: 180,
            text: "Sketch the AI action layer",
            style: style
        )
        workspace.canvasObjects.append(object)

        #expect(object.kind == .stickyNote)
        #expect(object.text == "Sketch the AI action layer")
        #expect(object.frame == CGRect(x: 40, y: 80, width: 260, height: 180))
        #expect(object.style == style)
        #expect(object.workspace?.id == workspace.id)
        #expect(workspace.canvasObjects.map(\.id).contains(object.id))
    }

    @Test func clipBackedObjectReferencesClipWithoutCopyingContent() {
        let clip = Clip(content: "Original clipboard text", origin: .clipboard)
        let object = CanvasObject(
            kind: .clipNote,
            clip: clip,
            x: 10,
            y: 20,
            width: 220,
            height: 140
        )

        #expect(object.kind == .clipNote)
        #expect(object.clip?.id == clip.id)
        #expect(object.text.isEmpty)

        clip.content = "Edited source content"

        #expect(object.displayText == "Edited source content")
    }

    @Test func connectorCanTargetObjectsOrFreePoints() {
        let sourceID = UUID()
        let destinationID = UUID()
        let connector = CanvasObject(
            kind: .connector,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            connector: CanvasConnector(
                start: CanvasConnectorEndpoint(
                    objectID: sourceID,
                    point: CGPointCodable(x: 10, y: 20),
                    anchor: .trailing
                ),
                end: CanvasConnectorEndpoint(
                    objectID: destinationID,
                    point: CGPointCodable(x: 240, y: 60),
                    anchor: .leading
                )
            )
        )

        #expect(connector.kind == .connector)
        #expect(connector.connector?.start.objectID == sourceID)
        #expect(connector.connector?.start.anchor == .trailing)
        #expect(connector.connector?.end.objectID == destinationID)
        #expect(connector.connector?.end.anchor == .leading)

        connector.connector = CanvasConnector(
            start: CanvasConnectorEndpoint(objectID: nil, point: CGPointCodable(x: 20, y: 30), anchor: .free),
            end: CanvasConnectorEndpoint(objectID: nil, point: CGPointCodable(x: 200, y: 90), anchor: .free)
        )

        #expect(connector.connector?.start.objectID == nil)
        #expect(connector.connector?.start.point.cgPoint == CGPoint(x: 20, y: 30))
        #expect(connector.connector?.end.anchor == .free)
    }

    @Test func softDeletedClipHidesClipBackedObjectWithoutDeletingObject() {
        let workspace = Workspace(name: "Board")
        let clip = Clip(content: "Temporary token", origin: .clipboard)
        let object = CanvasObject(
            kind: .clipNote,
            workspace: workspace,
            clip: clip,
            x: 0,
            y: 0,
            width: 220,
            height: 140
        )
        workspace.canvasObjects.append(object)

        #expect(object.isVisible)

        clip.softDelete()

        #expect(!object.isVisible)
        #expect(workspace.canvasObjects.count == 1)
        #expect(workspace.canvasObjects.first?.id == object.id)
    }
}
