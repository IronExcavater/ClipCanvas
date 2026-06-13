import CoreGraphics
import Testing
@testable import ClipCanvas

@Suite struct CanvasGridLayoutTests {
    @Test func usesSharedColumnWidthsAndRowHeights() {
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

    @Test func canCenterAroundViewportPoint() {
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
