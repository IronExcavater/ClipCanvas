import CoreGraphics
import Testing
@testable import ClipCanvas

@Suite struct CanvasScaleStepsTests {
    @Test func zoomCommandsUseDiscreteSteps() {
        #expect(CanvasScaleSteps.nextZoomIn(from: 1) == 1.25)
        #expect(CanvasScaleSteps.nextZoomOut(from: 1) == 0.8)
        #expect(CanvasScaleSteps.nearest(1.18) == 1.25)
        #expect(CanvasScaleSteps.fitting(1.18) == 1)
    }
}
