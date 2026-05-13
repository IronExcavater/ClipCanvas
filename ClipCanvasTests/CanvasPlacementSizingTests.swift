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
}
