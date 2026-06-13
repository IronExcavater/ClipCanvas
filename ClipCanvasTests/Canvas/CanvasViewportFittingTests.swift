import CoreGraphics
import Testing
@testable import ClipCanvas

@Suite struct CanvasViewportFittingTests {
    @Test func initialOriginCentersWorldOrigin() {
        let origin = CanvasViewportFitting.initialOrigin(
            viewportSize: CGSize(width: 390, height: 844),
            scale: 1
        )

        #expect(origin == CGPoint(x: -195, y: -422))
    }

    @Test func expansionKeepsObjectCenterWhenInsideBounds() {
        let current = CGRect(x: 40, y: 80, width: 220, height: 150)
        let frame = CanvasViewportFitting.frame(
            expanding: current,
            to: CGSize(width: 360, height: 240),
            bounds: CanvasRadiusBounds(radius: 1_000)
        )

        #expect(frame.midX == current.midX)
        #expect(frame.midY == current.midY)
        #expect(frame.size == CGSize(width: 360, height: 240))
    }

    @Test func viewportOriginMovesOnlyEnoughToRevealFrame() {
        let target = CGRect(x: 360, y: 300, width: 360, height: 240)
        let origin = CanvasViewportFitting.origin(
            revealing: target,
            currentOrigin: .zero,
            viewportSize: CGSize(width: 390, height: 844),
            scale: 1,
            bounds: CanvasRadiusBounds(radius: 2_000),
            margin: 24
        )

        #expect(origin.x == 354)
        #expect(origin.y == 0)
    }
}
