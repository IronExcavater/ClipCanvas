import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct TrashRetentionServiceTests {
    @Test func purgeExpiredWorkspaceDeletesCanvasObjects() throws {
        let context = try ModelContextFactory.makeContext()
        let workspace = Workspace(name: "Expired", isActive: true)
        workspace.deletedAt = Date(timeIntervalSince1970: 10)
        workspace.createNote(
            centeredAt: CGPoint(x: 100, y: 100),
            size: CGSize(width: 220, height: 140),
            text: "Delete me"
        )
        context.insert(workspace)

        TrashRetentionService.purgeExpired(
            in: context,
            retentionDays: 1,
            now: Date(timeIntervalSince1970: 10 + 2 * 24 * 60 * 60)
        )

        #expect(try context.fetch(FetchDescriptor<Workspace>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CanvasObject>()).isEmpty)
    }

    @Test func purgeExpiredChatDeletesChat() throws {
        let context = try ModelContextFactory.makeContext()
        let chat = AIChat(title: "Expired")
        chat.deletedAt = Date(timeIntervalSince1970: 10)
        context.insert(chat)

        TrashRetentionService.purgeExpired(
            in: context,
            retentionDays: 1,
            now: Date(timeIntervalSince1970: 10 + 2 * 24 * 60 * 60)
        )

        #expect(try context.fetch(FetchDescriptor<AIChat>()).isEmpty)
    }
}
