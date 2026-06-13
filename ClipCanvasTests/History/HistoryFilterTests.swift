import Foundation
import Testing
@testable import ClipCanvas

@Suite struct HistoryFilterTests {

    // MARK: - Matching

    @Test func emptySearchMatchesAll() {
        let filter = HistoryFilter()
        let clip = Clip(content: "Hello world", origin: .clipboard)
        #expect(filter.matches(clip))
    }

    @Test func searchMatchesCaseInsensitive() {
        let filter = HistoryFilter()
        filter.search = "hello"
        let clip = Clip(content: "Hello world", origin: .clipboard)
        #expect(filter.matches(clip))
    }

    @Test func searchExcludesNonMatching() {
        let filter = HistoryFilter()
        filter.search = "xyz"
        let clip = Clip(content: "Hello world", origin: .clipboard)
        #expect(!filter.matches(clip))
    }

    @Test func builtInTagFilterMatchesClipType() {
        let filter = HistoryFilter()
        filter.type = .url
        let urlClip = Clip(content: "https://apple.com", origin: .clipboard)
        let textClip = Clip(content: "Hello", origin: .clipboard)
        #expect(filter.matches(urlClip))
        #expect(!filter.matches(textClip))
    }

    @Test func userTagFilterMatchesAssignedTag() {
        let filter = HistoryFilter()
        let tag = ClipTag(name: "Research", colorHex: "#0EA5E9", isBuiltIn: false, sortIndex: 20)
        let tagged = Clip(content: "Tagged note", origin: .typed)
        tagged.tags = [tag]
        let untagged = Clip(content: "Untagged note", origin: .typed)

        filter.userTagID = tag.id

        #expect(filter.matches(tagged))
        #expect(!filter.matches(untagged))
    }

    @Test func nilTagMatchesAll() {
        let filter = HistoryFilter()
        filter.type = nil
        filter.userTagID = nil
        let clip = Clip(content: "https://apple.com", origin: .clipboard)
        #expect(filter.matches(clip))
    }

    // MARK: - Selection removed

    @Test func historyFilterOwnsSearchTypeAndUserTag() {
        let filter = HistoryFilter()
        let tagID = UUID()
        filter.search = "hello"
        filter.type = .text
        filter.userTagID = tagID
        #expect(filter.search == "hello")
        #expect(filter.type == .text)
        #expect(filter.userTagID == tagID)
    }
}
