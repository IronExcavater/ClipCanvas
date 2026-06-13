import CoreGraphics
import Testing
@testable import ClipCanvas

@Suite struct CanvasViewportBoundsTests {
    @Test func radiusHasMinimumAndExpandsWithContentWeight() {
        let viewport = CGSize(width: 390, height: 844)

        let empty = CanvasViewportBounds.radius(
            forObjectSizes: [],
            viewportSize: viewport,
            scale: 1
        )
        let large = CanvasViewportBounds.radius(
            forObjectSizes: [
                CGSize(width: 1_000, height: 800),
                CGSize(width: 1_000, height: 800),
                CGSize(width: 1_000, height: 800),
            ],
            viewportSize: viewport,
            scale: 1
        )

        #expect(empty.radius == CanvasViewportBounds.minimumRadius)
        #expect(large.radius > empty.radius)
    }

    @Test func boundedOriginClampsViewportCenterToBounds() {
        let viewport = CGSize(width: 200, height: 100)
        let bounds = CanvasRadiusBounds(radius: 100)
        let proposed = CGPoint(x: 150, y: -50)

        let clamped = CanvasViewportBounds.boundedOrigin(
            proposed,
            viewportSize: viewport,
            scale: 1,
            bounds: bounds,
            rubberBand: false
        )
        let rubberBanded = CanvasViewportBounds.boundedOrigin(
            proposed,
            viewportSize: viewport,
            scale: 1,
            bounds: bounds,
            rubberBand: true
        )

        #expect(clamped == CGPoint(x: 0, y: -50))
        #expect(rubberBanded == CGPoint(x: 36, y: -50))
    }

    @Test func objectClampKeepsTopLeftInsideCircularBounds() {
        let bounds = CanvasRadiusBounds(radius: 200)
        let topLeft = CGPoint(x: 300, y: -50)
        let size = CGSize(width: 100, height: 100)

        let clamped = bounds.clampedTopLeft(topLeft, size: size)

        #expect(abs(clamped.x - 79.28932188134524) < 0.001)
        #expect(abs(clamped.y - -50) < 0.001)
    }

    @Test func viewportCenterAndOriginRoundTrip() {
        let origin = CGPoint(x: -120, y: 80)
        let viewport = CGSize(width: 300, height: 600)
        let center = CanvasViewportBounds.viewportCenter(origin: origin, viewportSize: viewport, scale: 2)

        let roundTrip = CanvasViewportBounds.origin(forCenter: center, viewportSize: viewport, scale: 2)

        #expect(roundTrip == origin)
    }
}
