import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct PrivateClipRetentionTests {
    @Test func privateClipsGetDefaultExpiry() throws {
        let before = Date()

        let clip = Clip(
            content: "password: hunter2",
            origin: .clipboard,
            sensitivity: .privateContent,
            sensitivityReason: .secretKeyword
        )

        let expiresAt = try #require(clip.expiresAt)
        #expect(expiresAt.timeIntervalSince(before) >= PrivateClipRetentionPolicy.defaultExpiryInterval - 2)
        #expect(expiresAt.timeIntervalSince(before) <= PrivateClipRetentionPolicy.defaultExpiryInterval + 2)
        #expect(clip.sensitivityReason == .secretKeyword)
    }

    @Test func nonPrivateClipsDoNotExpire() {
        let clip = Clip(content: "Buy oat milk", origin: .clipboard, sensitivity: .normal)

        #expect(clip.expiresAt == nil)
    }

    @Test func purgeExpiredPrivateClipsDeletesCanvasObjects() throws {
        let context = try makeContext()
        let workspace = Workspace(name: "Private")
        let clip = Clip(
            content: "password: hunter2",
            origin: .clipboard,
            sensitivity: .privateContent,
            sensitivityReason: .secretKeyword
        )
        clip.expiresAt = Date(timeIntervalSince1970: 10)
        let object = CanvasObject(kind: .clipNote, workspace: workspace, clip: clip, x: 0, y: 0, width: 220, height: 140)
        workspace.canvasObjects.append(object)
        clip.canvasObjects.append(object)
        context.insert(workspace)
        context.insert(clip)
        context.insert(object)

        let deleted = PrivateClipRetentionService.purgeExpired(in: context, now: Date(timeIntervalSince1970: 11))

        #expect(deleted == 1)
        #expect(try context.fetch(FetchDescriptor<Clip>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CanvasObject>()).isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self,
            AIChat.self, ChatMessage.self, ChatAttachment.self, AIToolEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}
