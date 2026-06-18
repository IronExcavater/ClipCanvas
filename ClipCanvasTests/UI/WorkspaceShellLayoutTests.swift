import CoreGraphics
import Testing
@testable import ClipCanvas

@Suite struct WorkspaceShellLayoutTests {
    @Test func compactPortraitUsesOverlayDrawer() {
        let layout = WorkspaceShellLayout.resolve(
            width: 430,
            isCompactWidth: true,
            prefersDesktopLayout: false
        )

        #expect(layout == .overlayDrawer)
    }

    @Test func compactLandscapeUsesSplitLayout() {
        let layout = WorkspaceShellLayout.resolve(
            width: 820,
            isCompactWidth: true,
            prefersDesktopLayout: false
        )

        #expect(layout == .split)
    }

    @Test func wideAndDesktopLayoutsPreferInspector() {
        #expect(WorkspaceShellLayout.resolve(width: 1_020, isCompactWidth: false, prefersDesktopLayout: false) == .splitWithInspector)
        #expect(WorkspaceShellLayout.resolve(width: 760, isCompactWidth: false, prefersDesktopLayout: true) == .splitWithInspector)
    }
}
