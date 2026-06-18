import CoreGraphics
import Testing
@testable import ClipCanvas

@Suite struct CanvasEditOverlayLayoutTests {
    @Test func topChromeHeightMovesEditFrameBelowSearchBar() {
        let base = CanvasEditOverlayLayout.availableFrame(
            viewportSize: CGSize(width: 430, height: 900),
            topBarContentHeight: 60,
            keyboardHeight: 0,
            safeAreaBottom: 34
        )
        let searching = CanvasEditOverlayLayout.availableFrame(
            viewportSize: CGSize(width: 430, height: 900),
            topBarContentHeight: 118,
            keyboardHeight: 0,
            safeAreaBottom: 34
        )

        #expect(base.minY == 72)
        #expect(searching.minY == 130)
        #expect(searching.height == base.height - 58)
    }

    @Test func keyboardReducesAvailableEditHeightWithoutChangingTopPosition() {
        let hidden = CanvasEditOverlayLayout.availableFrame(
            viewportSize: CGSize(width: 430, height: 900),
            topBarContentHeight: 60,
            keyboardHeight: 0,
            safeAreaBottom: 34
        )
        let shown = CanvasEditOverlayLayout.availableFrame(
            viewportSize: CGSize(width: 430, height: 900),
            topBarContentHeight: 60,
            keyboardHeight: 320,
            safeAreaBottom: 34
        )

        #expect(shown.minY == hidden.minY)
        #expect(shown.height < hidden.height)
    }
}
