import Testing
@testable import ClipCanvas

@Suite struct CanvasModeTests {
    @Test func canvasModesMatchWorkspacePlanOrder() {
        #expect(CanvasMode.allCases == [.pan, .edit, .draw])
        #expect(CanvasMode.pan.allowsCanvasPan)
        #expect(!CanvasMode.edit.allowsCanvasPan)
        #expect(!CanvasMode.draw.allowsCanvasPan)
    }

    @Test func emptyToolbarShowsPasteAndAllModes() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, mode: .pan)

        #expect(configuration.items == [
            .paste,
            .divider,
            .mode(.pan),
            .mode(.edit),
            .mode(.draw)
        ])
    }

    @Test func panSelectionToolbarShowsCopyInfoAndArrange() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .pan)

        #expect(configuration.items == [
            .askAI,
            .divider,
            .arrangeSelection, .details,
            .divider,
            .delete
        ])
    }

    @Test func editSelectionToolbarShowsEditTagsAndDelete() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .edit)

        #expect(configuration.items == [
            .editContent,
            .divider,
            .color, .manageTags,
            .divider,
            .delete
        ])
    }

    @Test func drawToolbarKeepsModeSwitcherVisible() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, mode: .draw)

        #expect(configuration.items.starts(with: [
            .mode(.pan),
            .mode(.edit),
            .mode(.draw),
        ]))
        #expect(configuration.items.contains(.drawPen))
        #expect(configuration.items.contains(.drawClear))
    }
}
