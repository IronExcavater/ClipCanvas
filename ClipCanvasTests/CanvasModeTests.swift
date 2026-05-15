import Testing
@testable import ClipCanvas

@Suite struct CanvasModeTests {
    @Test func canvasModesMatchWorkspacePlanOrder() {
        #expect(CanvasMode.allCases == [.pan, .edit, .draw])
        #expect(CanvasMode.pan.allowsCanvasPan)
        #expect(CanvasMode.edit.allowsCanvasPan)
        #expect(!CanvasMode.draw.allowsCanvasPan)
    }

    @Test func emptyToolbarShowsPasteAndAllModes() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, mode: .pan)

        #expect(configuration.items == [
            .paste,
            .newNote,
            .askAI,
            .divider,
            .mode(.pan),
            .mode(.edit),
            .mode(.draw)
        ])
    }

    @Test func editEmptyToolbarAddsVisibleNewNoteAction() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, mode: .edit)

        #expect(configuration.items == [
            .closeMode,
            .newNote,
            .color
        ])
    }

    @Test func panSelectionToolbarShowsSelectionActions() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .pan)

        #expect(configuration.items == [
            .arrangeSelection,
            .details,
            .askAI,
            .delete
        ])
    }

    @Test func editTextToolbarShowsFormattingActions() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .edit, isEditing: true)

        #expect(configuration.items == [
            .closeMode,
            .formatBold,
            .formatBullet,
            .formatHighlight
        ])
    }

    @Test func editSelectionToolbarShowsEditTagsAndDelete() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .edit)

        #expect(configuration.items == [
            .closeMode,
            .editContent,
            .color,
            .manageTags,
            .details,
            .delete
        ])
    }

    @Test func drawToolbarUsesCloseButtonInsteadOfMainModeTools() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, mode: .draw)

        #expect(configuration.items.first == .closeMode)
        #expect(!configuration.items.contains(.mode(.pan)))
        #expect(!configuration.items.contains(.mode(.edit)))
        #expect(!configuration.items.contains(.mode(.draw)))
        #expect(configuration.items.contains(.drawPen))
        #expect(!configuration.items.contains(.paste))
    }
}
