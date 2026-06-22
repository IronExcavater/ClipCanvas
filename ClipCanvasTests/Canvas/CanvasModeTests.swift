import Testing
@testable import ClipCanvas

@Suite struct CanvasModeTests {
    @Test func canvasModesMatchWorkspacePlanOrder() {
        #expect(CanvasMode.allCases == [.pan, .edit, .draw])
        #expect(CanvasMode.pan.allowsCanvasPan)
        #expect(CanvasMode.edit.allowsCanvasPan)
        #expect(!CanvasMode.draw.allowsCanvasPan)
    }

    @Test func emptyToolbarShowsCreationPalette() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, mode: .pan)

        #expect(configuration.items == [
            .askAI,
            .paste,
            .newNote,
            .insertImage,
            .mode(.draw)
        ])
    }

    @Test func editEmptyToolbarShowsCreationTools() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 0, mode: .edit)

        #expect(configuration.items == [
            .askAI,
            .paste,
            .closeMode,
            .newNote,
            .insertImage,
        ])
    }

    @Test func panSelectionToolbarShowsSelectionActions() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .pan, selectionKind: .clip)

        #expect(configuration.items == [
            .askAI,
            .copyToClipboard,
            .editContent,
            .details,
            .duplicate,
            .arrangeSelection,
            .delete
        ])
    }

    @Test func panStandaloneTextSelectionOmitsUnavailableDetails() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .pan, selectionKind: .text)

        #expect(configuration.items == [
            .askAI,
            .copyToClipboard,
            .editContent,
            .duplicate,
            .arrangeSelection,
            .delete
        ])
    }

    @Test func panMultiSelectionOmitsSingleItemDetails() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 2, mode: .pan)

        #expect(configuration.items == [
            .askAI,
            .copyToClipboard,
            .duplicate,
            .arrangeSelection,
            .delete
        ])
    }

    @Test func editTextToolbarShowsFormattingActions() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .edit, isEditing: true)

        #expect(configuration.items == [
            .askAI,
            .copyToClipboard,
            .closeMode,
            .formatPanel,
            .formatList,
            .formatQuote,
            .formatLink,
            .formatOutdent,
            .formatIndent,
            .formatBold,
            .formatItalic,
            .formatUnderline,
            .formatStrikethrough,
            .formatHighlight
        ])
    }

    @Test func editSelectionToolbarKeepsCreationToolsUntilActivelyEditing() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .edit, selectionKind: .text)

        #expect(configuration.items == [
            .askAI,
            .paste,
            .closeMode,
            .newNote,
            .insertImage,
        ])
    }

    @Test func editImageSelectionDoesNotMoveIntoOverlayTools() {
        let configuration = CanvasToolbarConfiguration.make(selectedCount: 1, mode: .edit, selectionKind: .image)

        #expect(configuration.items == [
            .askAI,
            .paste,
            .closeMode,
            .newNote,
            .insertImage,
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
