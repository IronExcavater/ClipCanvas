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
        #expect(message?.content == "")
        #expect(message?.sortedAttachments.compactMap(\.canvasObject?.id) == [clipObject.id, stickyObject.id])
        #expect(message?.sortedAttachments.first?.clip?.id == clip.id)
        #expect(chat.title == "2 Canvas Cards")
        #expect(chat.messages.count == 1)
    }

    @Test func chatCommandCleansUpAttachedClipThroughWorkspaceTools() async throws {
        let context = try ModelContextFactory.makeContext()
        let workspace = Workspace(name: "Board")
        let clip = Clip(content: "  Clean     this\n\nnote  ", origin: .clipboard)
        let object = CanvasObject(kind: .clipNote, workspace: workspace, clip: clip, x: 0, y: 0, width: 220, height: 140)
        workspace.canvasObjects = [object]
        context.insert(workspace)
        context.insert(clip)
        context.insert(object)
        let chat = AIChatService.createChat(in: context, workspace: workspace)
        _ = AIChatService.attachObjects([object], to: chat, in: context)
        let userMessage = ChatMessage(role: .user, content: "Clean up this card")
        userMessage.chat = chat
        chat.messages.append(userMessage)
        context.insert(userMessage)
        let assistant = ChatMessage(role: .assistant, content: "")
        assistant.chat = chat
        chat.messages.append(assistant)
        context.insert(assistant)

        await AIChatCommandRouter.respond(to: userMessage, with: assistant, in: context)

        #expect(clip.content == "Clean this\nnote")
        #expect(assistant.toolEvents.first?.status == .completed)
        #expect(assistant.content == "Cleaned up 1 note.")
    }

    @Test func chatCommandDuplicatesAttachedCanvasObjectThroughWorkspaceTools() async throws {
        let context = try ModelContextFactory.makeContext()
        let workspace = Workspace(name: "Board")
        let object = CanvasObject(
            kind: .stickyNote,
            workspace: workspace,
            x: 10,
            y: 20,
            width: 220,
            height: 140,
            text: "Duplicate me"
        )
        workspace.canvasObjects = [object]
        context.insert(workspace)
        context.insert(object)
        let chat = AIChatService.createChat(in: context, workspace: workspace)
        _ = AIChatService.attachObjects([object], to: chat, in: context)
        let userMessage = ChatMessage(role: .user, content: "Duplicate this card")
        userMessage.chat = chat
        chat.messages.append(userMessage)
        context.insert(userMessage)
        let assistant = ChatMessage(role: .assistant, content: "")
        assistant.chat = chat
        chat.messages.append(assistant)
        context.insert(assistant)

        await AIChatCommandRouter.respond(to: userMessage, with: assistant, in: context)

        #expect(workspace.canvasObjects.count == 2)
        #expect(workspace.canvasObjects.contains { $0.text == "Duplicate me" && $0.x == 38 && $0.y == 48 })
        #expect(assistant.toolEvents.first?.status == .completed)
        #expect(assistant.content == "Duplicated 1 card.")
    }
}
