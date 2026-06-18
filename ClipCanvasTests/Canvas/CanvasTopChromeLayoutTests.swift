import CoreGraphics
import Testing
@testable import ClipCanvas

@Suite struct CanvasTopChromeLayoutTests {
    @Test func expectedHeightTracksSearchState() {
        #expect(CanvasTopChromeLayout.expectedHeight(searchActive: false) == 60)
        #expect(CanvasTopChromeLayout.expectedHeight(searchActive: true) == 118)
    }

    @Test func resolvedHeightUsesExpectedHeightForInvalidMeasurements() {
        #expect(CanvasTopChromeLayout.resolvedHeight(measuredHeight: 0, expectedHeight: 118) == 118)
    }

    @Test func resolvedHeightCanShrinkWhenSearchCloses() {
        let closed = CanvasTopChromeLayout.expectedHeight(searchActive: false)

        #expect(CanvasTopChromeLayout.resolvedHeight(measuredHeight: closed, expectedHeight: closed) == closed)
    }
}
