import CoreGraphics
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

    @Test func textResizeSnapsToCharacterAndLineSteps() {
        let size = CanvasPlacementSizing.snappedSize(
            CGSize(width: 219, height: 151),
            for: Clip(content: "Note", origin: .typed)
        )

        #expect((size.width - CanvasPlacementSizing.contentChrome.width)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.estimatedCharacterWidth) == 0)
        #expect((size.height - CanvasPlacementSizing.contentChrome.height)
            .truncatingRemainder(dividingBy: CanvasPlacementSizing.estimatedLineHeight) == 0)
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
