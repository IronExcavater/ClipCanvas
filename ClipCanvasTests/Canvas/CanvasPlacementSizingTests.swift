import CoreGraphics
import Foundation
import Testing
@testable import ClipCanvas

@Suite struct CanvasPlacementSizingTests {
    @Test func doubleTapResizeExpandsThenCollapses() {
        let placement = CanvasPlacement(clip: Clip(content: String(repeating: "Long content ", count: 40), origin: .clipboard), x: 0, y: 0)
        let first = CanvasPlacementSizing.toggledSize(for: placement)
        placement.width = Double(first.width)
        placement.height = Double(first.height)

        let second = CanvasPlacementSizing.toggledSize(for: placement)

        #expect(first.height > CanvasPlacementSizing.defaultSize.height)
        #expect(second == CanvasPlacementSizing.defaultSize)
    }

    @Test func doubleTapResizePrioritizesAvailableScreenWidth() {
        let object = CanvasObject(
            kind: .stickyNote,
            x: 0,
            y: 0,
            width: CanvasPlacementSizing.defaultSize.width,
            height: CanvasPlacementSizing.defaultSize.height,
            text: "A short note"
        )

        let size = CanvasPlacementSizing.toggledSize(for: object, availableScreenWidth: 390)

        #expect(size.width > CanvasPlacementSizing.defaultSize.width)
        #expect(size.width <= 390)
        #expect((size.width - CanvasPlacementSizing.contentChrome.width)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.characterWidth) == 0)
    }

    @Test func editingSizeUsesFinalWidthForLineHeight() {
        let text = String(repeating: "word ", count: 80)
        let object = CanvasObject(
            kind: .stickyNote,
            x: 0,
            y: 0,
            width: CanvasPlacementSizing.defaultSize.width,
            height: CanvasPlacementSizing.defaultSize.height,
            text: text
        )

        let size = CanvasPlacementSizing.editingSize(
            for: object,
            viewportSize: CGSize(width: 390, height: 740),
            scale: 1
        )

        #expect(size.width <= 390)
        #expect(size.height < size.width)
        #expect((size.height - CanvasPlacementSizing.contentChrome.height)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.lineHeight) == 0)
    }

    @Test func textResizeSnapsToCharacterAndLineSteps() {
        let size = CanvasPlacementSizing.snappedSize(
            CGSize(width: 229, height: 163),
            for: Clip(content: "Note", origin: .typed)
        )

        #expect((CanvasPlacementSizing.defaultSize.width - CanvasPlacementSizing.contentChrome.width)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.characterWidth) == 0)
        #expect((CanvasPlacementSizing.defaultSize.height - CanvasPlacementSizing.contentChrome.height)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.lineHeight) == 0)
        #expect((size.width - CanvasPlacementSizing.contentChrome.width)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.characterWidth) == 0)
        #expect((size.height - CanvasPlacementSizing.contentChrome.height)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.lineHeight) == 0)
    }

    @Test func resizePreviewIsFluidButCommitSnapsToTextGrid() {
        let session = CanvasResizeSession(
            objectID: UUID(),
            startSize: CanvasPlacementSizing.defaultSize,
            translation: CGSize(width: 13, height: 17)
        )
        let clip = Clip(content: "Note", origin: .typed)

        let preview = CanvasPlacementSizing.previewSize(for: session, scale: 1)
        let committed = CanvasPlacementSizing.committedSize(for: session, scale: 1, clip: clip)

        #expect(preview == CGSize(
            width: CanvasPlacementSizing.defaultSize.width + 13,
            height: CanvasPlacementSizing.defaultSize.height + 17
        ))
        #expect(committed != preview)
        #expect((committed.width - CanvasPlacementSizing.contentChrome.width)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.characterWidth) == 0)
        #expect((committed.height - CanvasPlacementSizing.contentChrome.height)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.lineHeight) == 0)
    }

}
