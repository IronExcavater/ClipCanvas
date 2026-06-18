import Testing
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
}
