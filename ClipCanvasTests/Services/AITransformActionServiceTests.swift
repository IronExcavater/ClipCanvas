import CoreGraphics
import SwiftData
import Testing
@testable import ClipCanvas

@MainActor
@Suite struct AITransformActionServiceTests {
    @Test func appliesTransformToClipBackedAndPlainCanvasCards() throws {
        let context = try ModelContextFactory.makeContext()
        let workspace = Workspace(name: "Board")
        let clip = Clip(content: "  Clip   note\n\ntext  ", origin: .clipboard)
        let clipObject = CanvasObject(
            kind: .clipNote,
            workspace: workspace,
            clip: clip,
            x: 0,
            y: 0,
            width: 220,
            height: 140
        )
        let note = CanvasObject(
            kind: .stickyNote,
            workspace: workspace,
            x: 240,
            y: 0,
            width: 220,
            height: 140,
            text: "  Sticky   note\n\ntext  "
        )
        workspace.canvasObjects = [clipObject, note]
        context.insert(workspace)
        context.insert(clip)
        context.insert(clipObject)
        context.insert(note)

        let result = AITransformActionService.apply(
            .cleanUp,
            to: [clipObject, note],
            workspace: workspace,
            in: context
        )

        #expect(result.success)
        #expect(clip.content == "Clip note\ntext")
        #expect(note.text == "Sticky note\ntext")
        #expect(result.changedClipIDs == [clip.id])
        #expect(result.changedObjectIDs == [note.id])
    }
}
