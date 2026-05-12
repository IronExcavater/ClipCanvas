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
}
