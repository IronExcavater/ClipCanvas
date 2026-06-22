import Testing
import SwiftUI
@testable import ClipCanvas

@Suite struct MarkdownPreviewTests {
    @Test func parsesBulletsWithoutIncludingMarkersInBody() {
        let blocks = MarkdownPreview.blocks(for: "- **Bold** and *italic*\n  - Nested")

        #expect(blocks.count == 2)
        if case .bullet(let first, let firstLevel) = blocks[0].kind {
            #expect(first == "**Bold** and *italic*")
            #expect(firstLevel == 0)
        } else {
            Issue.record("Expected first block to be a bullet")
        }

        if case .bullet(let second, let secondLevel) = blocks[1].kind {
            #expect(second == "Nested")
            #expect(secondLevel == 1)
        } else {
            Issue.record("Expected second block to be a nested bullet")
        }
    }

    @Test func parsesOrderedListMarkersAsOrderedPreviewBlocks() {
        let blocks = MarkdownPreview.blocks(for: "1. First item\n2. Second item")

        #expect(blocks.count == 2)
        if case .ordered(let first, let number, let level) = blocks[0].kind {
            #expect(first == "First item")
            #expect(number == 1)
            #expect(level == 0)
        } else {
            Issue.record("Expected ordered list item to render as an ordered preview")
        }
    }

    @Test func parsesChecklistMarkersAsChecklistPreviewBlocks() {
        let blocks = MarkdownPreview.blocks(for: "- [ ] Todo\n- [x] Done")

        #expect(blocks.count == 2)
        if case .checklist(let first, let checked, let level) = blocks[0].kind {
            #expect(first == "Todo")
            #expect(checked == false)
            #expect(level == 0)
        } else {
            Issue.record("Expected unchecked checklist item")
        }
        if case .checklist(let second, let checked, _) = blocks[1].kind {
            #expect(second == "Done")
            #expect(checked == true)
        } else {
            Issue.record("Expected checked checklist item")
        }
    }

    @Test func parsesMonostyledBlocksWithoutIndentMarker() {
        let blocks = MarkdownPreview.blocks(for: "    let value = 1")

        #expect(blocks.count == 1)
        if case .monostyled(let content) = blocks[0].kind {
            #expect(content == "let value = 1")
        } else {
            Issue.record("Expected indented note text to render as a monostyled block")
        }
    }

    @Test func rendersHighlightsWithoutMarkers() {
        let attributed = MarkdownPreview.attributedString(for: "Ship ==highlighted **text**== today")

        #expect(String(attributed.characters) == "Ship highlighted text today")
        #expect(attributed.runs.contains { $0.backgroundColor != nil })
    }

    @Test func rendersBoldItalicCombinationWithoutMarkers() {
        let attributed = MarkdownPreview.attributedString(for: "***Important*** and *quiet*")

        #expect(String(attributed.characters) == "Important and quiet")
        #expect(attributed.runs.contains { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
            && run.inlinePresentationIntent?.contains(.emphasized) == true
        })
    }

    @Test func preservesUnmatchedMarkersLiterally() {
        let attributed = MarkdownPreview.attributedString(for: "Keep ==unfinished and **open")

        #expect(String(attributed.characters) == "Keep ==unfinished and **open")
    }

    @Test func rendersMarkdownLinksAsTappableText() throws {
        let attributed = MarkdownPreview.attributedString(for: "Open [Card](clipcanvas://object/00000000-0000-0000-0000-000000000001)")

        #expect(String(attributed.characters) == "Open Card")
        let link = try #require(attributed.runs.compactMap(\.link).first)
        #expect(link.absoluteString == "clipcanvas://object/00000000-0000-0000-0000-000000000001")
    }

    @Test func rendersUnderlineAndStrikethroughWithoutMarkers() {
        let attributed = MarkdownPreview.attributedString(for: "<u>under</u> and ~~gone~~")

        #expect(String(attributed.characters) == "under and gone")
        #expect(attributed.runs.contains { $0.underlineStyle != nil })
        #expect(attributed.runs.contains { $0.strikethroughStyle != nil })
    }

    @Test func rendersColoredHighlightsWithoutMarkers() {
        let attributed = MarkdownPreview.attributedString(for: "==purple:marked==")

        #expect(String(attributed.characters) == "marked")
        #expect(attributed.runs.contains { $0.backgroundColor != nil })
    }

    @Test func masksSensitiveMarkdownWithoutRemovingOtherText() throws {
        let attributed = MarkdownPreview.attributedString(
            for: "password: ||hunter2|| for staging",
            revealedSensitiveParts: []
        )

        #expect(String(attributed.characters) == "password: ••••••• for staging")
        let link = try #require(attributed.runs.compactMap(\.link).first)
        #expect(link.scheme == "clipcanvas-sensitive")
    }

    @Test func revealedSensitiveMarkdownShowsOnlyThatPart() {
        let hidden = SensitiveTextPart(text: "hunter2", occurrence: 0).id
        let attributed = MarkdownPreview.attributedString(
            for: "password: ||hunter2|| and token ||abc123||",
            revealedSensitiveParts: [hidden]
        )

        #expect(String(attributed.characters) == "password: hunter2 and token ••••••")
    }
}

@Suite struct NoteTextFormattingEngineTests {
    @Test func underlineWrapsSelection() {
        let result = NoteTextFormattingEngine.apply(.underline, to: "hello", selectedRange: NSRange(location: 0, length: 5))

        #expect(result.text == "<u>hello</u>")
    }

    @Test func strikethroughWrapsSelection() {
        let result = NoteTextFormattingEngine.apply(.strikethrough, to: "done", selectedRange: NSRange(location: 0, length: 4))

        #expect(result.text == "~~done~~")
    }

    @Test func checklistAddsMarkersToSelectedLines() {
        let result = NoteTextFormattingEngine.apply(.list(.checklist), to: "one\ntwo", selectedRange: NSRange(location: 0, length: 7))

        #expect(result.text == "- [ ] one\n- [ ] two")
    }

    @Test func numberedListRenumbersSelectedLines() {
        let result = NoteTextFormattingEngine.apply(.list(.numbered), to: "one\ntwo", selectedRange: NSRange(location: 0, length: 7))

        #expect(result.text == "1. one\n2. two")
    }

    @Test func listCommandCreatesMarkerInEmptyNote() {
        let bullet = NoteTextFormattingEngine.apply(.list(.bullet), to: "", selectedRange: NSRange(location: 0, length: 0))
        let numbered = NoteTextFormattingEngine.apply(.list(.numbered), to: "", selectedRange: NSRange(location: 0, length: 0))
        let checklist = NoteTextFormattingEngine.apply(.list(.checklist), to: "", selectedRange: NSRange(location: 0, length: 0))

        #expect(bullet.text == "* ")
        #expect(numbered.text == "1. ")
        #expect(checklist.text == "- [ ] ")
    }

    @Test func indentAndOutdentListItems() {
        let indented = NoteTextFormattingEngine.apply(.indent, to: "- one", selectedRange: NSRange(location: 0, length: 5))
        let outdented = NoteTextFormattingEngine.apply(.outdent, to: indented.text, selectedRange: NSRange(location: 0, length: indented.text.count))

        #expect(indented.text == "  - one")
        #expect(outdented.text == "- one")
    }

    @Test func returnFromListItemCreatesNextItem() {
        let result = NoteTextFormattingEngine.applyNewline(in: "- one", selectedRange: NSRange(location: 5, length: 0))

        #expect(result?.text == "- one\n- ")
    }

    @Test func returnFromEmptyListItemRemovesMarker() {
        let result = NoteTextFormattingEngine.applyNewline(in: "- ", selectedRange: NSRange(location: 2, length: 0))

        #expect(result?.text == "")
    }

    @Test func linkUsesDisplayTextAndURL() {
        let result = NoteTextFormattingEngine.apply(.link(url: "https://example.com", displayText: "Example"), to: "", selectedRange: NSRange(location: 0, length: 0))

        #expect(result.text == "[Example](https://example.com)")
    }
}
