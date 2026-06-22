import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct PrivateClipRetentionTests {
    @Test func privateClipsDoNotGetDefaultExpiry() {
        let clip = Clip(
            content: "password: hunter2",
            origin: .clipboard,
            sensitivity: .privateContent,
            sensitivityReason: .secretKeyword
        )

        #expect(clip.expiresAt == nil)
        #expect(clip.sensitivityReason == .secretKeyword)
    }

    @Test func nonPrivateClipsDoNotExpire() {
        let clip = Clip(content: "Buy oat milk", origin: .clipboard, sensitivity: .normal)

        #expect(clip.expiresAt == nil)
    }

    @Test func purgeExpiredPrivateClipsDeletesCanvasObjects() throws {
        let context = try ModelContextFactory.makeContext()
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

    @MainActor
    @Test func revealStoreTemporarilyRevealsPrivateClips() {
        let store = PrivateClipRevealStore(revealDuration: 10)
        let clip = Clip(content: "N0tArealP@ssword1", origin: .clipboard, sensitivity: .privateContent)
        let now = Date(timeIntervalSince1970: 100)

        #expect(!store.isRevealed(clip, at: now))

        store.reveal(clip, at: now)

        #expect(store.isRevealed(clip, at: now.addingTimeInterval(9)))
        #expect(!store.isRevealed(clip, at: now.addingTimeInterval(11)))
        #expect(store.purgeExpired(at: now.addingTimeInterval(11)) == 1)
    }
}
