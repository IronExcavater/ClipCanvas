import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct AppBootstrapTests {
    @Test func seedsBuiltInTagsOnce() throws {
        let context = try ModelContextFactory.makeCoreContext()

        AppBootstrap.ensureActiveWorkspace(in: context)
        AppBootstrap.ensureActiveWorkspace(in: context)

        let tags = try context.fetch(FetchDescriptor<ClipTag>())
        #expect(tags.count == ClipTag.builtInDefinitions.count)
    }
}
