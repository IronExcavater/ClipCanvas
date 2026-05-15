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

    @Test func zoomCommandsUseDiscreteSteps() {
        #expect(CanvasScaleSteps.nextZoomIn(from: 1) == 1.25)
        #expect(CanvasScaleSteps.nextZoomOut(from: 1) == 0.8)
        #expect(CanvasScaleSteps.nearest(1.18) == 1.25)
        #expect(CanvasScaleSteps.fitting(1.18) == 1)
    }

    @Test func gridLayoutUsesSharedColumnWidthsAndRowHeights() {
        let items = [
            CanvasGridLayoutItem(id: 0, size: CGSize(width: 100, height: 80)),
            CanvasGridLayoutItem(id: 1, size: CGSize(width: 120, height: 60)),
            CanvasGridLayoutItem(id: 2, size: CGSize(width: 90, height: 90)),
            CanvasGridLayoutItem(id: 3, size: CGSize(width: 70, height: 70)),
        ]

        let frames = CanvasGridLayout.frames(
            for: items,
            columns: 2,
            origin: CGPoint(x: 10, y: 20),
            spacing: CGSize(width: 12, height: 14)
        )

        #expect(frames.map(\.origin) == [
            CGPoint(x: 10, y: 20),
            CGPoint(x: 122, y: 20),
            CGPoint(x: 10, y: 114),
            CGPoint(x: 122, y: 114),
        ])
    }

    @Test func gridLayoutCanCenterAroundViewportPoint() {
        let items = [
            CanvasGridLayoutItem(id: "a", size: CGSize(width: 100, height: 80)),
            CanvasGridLayoutItem(id: "b", size: CGSize(width: 120, height: 60)),
            CanvasGridLayoutItem(id: "c", size: CGSize(width: 90, height: 90)),
        ]

        let frames = CanvasGridLayout.centeredFrames(
            for: items,
            columns: 2,
            center: .zero,
            spacing: CGSize(width: 12, height: 14)
        )

        #expect(frames.first?.origin == CGPoint(x: -116, y: -92))
        #expect(CanvasGridLayout.balancedColumnCount(for: 5) == 3)
    }
}
