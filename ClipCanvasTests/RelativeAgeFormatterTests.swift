import Foundation
import Testing
@testable import ClipCanvas

@Suite struct RelativeAgeFormatterTests {
    @Test func returnsBlankForSubsecondAges() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(RelativeAgeFormatter.shortString(since: now, now: now) == "")
    }

    @Test func formatsTwoLargestUnits() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let then = now.addingTimeInterval(-(3 * 24 * 60 * 60 + 4 * 60 * 60 + 12 * 60))
        #expect(RelativeAgeFormatter.shortString(since: then, now: now) == "3d 4h")
    }

    @Test func formatsYearsAndMonths() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let then = now.addingTimeInterval(-(400 * 24 * 60 * 60))
        #expect(RelativeAgeFormatter.shortString(since: then, now: now) == "1y 1mo")
    }
}

