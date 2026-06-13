import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct AIChatServiceTests {
    @Test func createsChatForActiveWorkspace() throws {
        let context = try ModelContextFactory.makeContext()
        let inactive = Workspace(name: "Inbox")
        let active = Workspace(name: "Board", isActive: true)
        context.insert(inactive)
        context.insert(active)

        let chat = AIChatService.createChat(in: context, workspaces: [inactive, active])

        #expect(chat.title == "Board AI")
        #expect(chat.workspace?.id == active.id)
        #expect(active.chats.contains { $0.id == chat.id })
        #expect((try context.fetch(FetchDescriptor<AIChat>())).count == 1)
    }

    @Test func attachesCanvasObjectsToMessage() throws {
        let context = try ModelContextFactory.makeContext()
        let workspace = Workspace(name: "Board")
        let clip = Clip(content: "Clip note", origin: .clipboard)
        let clipObject = CanvasObject(kind: .clipNote, workspace: workspace, clip: clip, x: 0, y: 0, width: 220, height: 140)
        let stickyObject = CanvasObject(kind: .stickyNote, workspace: workspace, x: 260, y: 0, width: 220, height: 140, text: "Sticky note")
        workspace.canvasObjects = [clipObject, stickyObject]
        context.insert(workspace)
        context.insert(clip)
        context.insert(clipObject)
        context.insert(stickyObject)
        let chat = AIChatService.createChat(in: context, workspace: workspace)

        let message = AIChatService.attachObjects([clipObject, stickyObject, clipObject], to: chat, in: context)

        #expect(message?.attachments.count == 2)
        #expect(message?.sortedAttachments.compactMap(\.canvasObject?.id) == [clipObject.id, stickyObject.id])
        #expect(message?.sortedAttachments.first?.clip?.id == clip.id)
        #expect(chat.title == "2 Canvas Cards")
        #expect(chat.messages.count == 1)
    }
}
