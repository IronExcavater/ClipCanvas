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
        filter.tag = .builtIn(.url)
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

        filter.tag = .user(tag.id)

        #expect(filter.matches(tagged))
        #expect(!filter.matches(untagged))
    }

    @Test func nilTagMatchesAll() {
        let filter = HistoryFilter()
        filter.tag = nil
        let clip = Clip(content: "https://apple.com", origin: .clipboard)
        #expect(filter.matches(clip))
    }

    // MARK: - Selection removed

    @Test func historyFilterOwnsSearchAndTag() {
        let filter = HistoryFilter()
        filter.search = "hello"
        filter.tag = .builtIn(.text)
        #expect(filter.search == "hello")
        #expect(filter.tag == .builtIn(.text))
    }
}
