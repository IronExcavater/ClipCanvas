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

    @Test func parsesOrderedListMarkersAsBulletPreviewBlocks() {
        let blocks = MarkdownPreview.blocks(for: "1. First item\n2. Second item")

        #expect(blocks.count == 2)
        if case .bullet(let first, let level) = blocks[0].kind {
            #expect(first == "First item")
            #expect(level == 0)
        } else {
            Issue.record("Expected ordered list item to render as a bullet preview")
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
}
