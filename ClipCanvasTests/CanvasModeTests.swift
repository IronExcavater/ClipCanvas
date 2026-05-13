import Testing
@testable import ClipCanvas

@Suite struct CanvasModeTests {
    @Test func canvasModesMatchWorkspacePlanOrder() {
        #expect(CanvasMode.allCases == [.normal, .edit, .draw])
        #expect(CanvasMode.normal.allowsCanvasPan)
        #expect(!CanvasMode.edit.allowsCanvasPan)
        #expect(!CanvasMode.draw.allowsCanvasPan)
    }

    @Test func emptyToolbarShowsPasteAndAllModes() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, canOpenLink: false)

        #expect(configuration.items == [
            .paste,
            .divider,
            .mode(.normal),
            .mode(.edit),
            .mode(.draw)
        ])
    }

    @Test func selectionToolbarShowsContextActions() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, canOpenLink: true)

        #expect(configuration.items == [
            .copy,
            .openLink,
            .divider,
            .details,
            .manageTags,
            .arrangeSelection,
            .divider,
            .delete
        ])
    }

    @Test func selectionToolbarOmitsLinkActionWhenUnavailable() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 3, canOpenLink: false)

        #expect(!configuration.items.contains(.openLink))
        #expect(configuration.items.contains(.copy))
        #expect(configuration.items.contains(.delete))
    }
}
