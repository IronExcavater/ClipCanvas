import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct AIChatModelTests {
    @Test func chatDefaultsToQuickModeAndUnpinned() {
        let chat = AIChat(title: "Workspace chat")

        #expect(chat.mode == .quick)
        #expect(!chat.isPinned)
        #expect(chat.openAIConversationID == nil)
        #expect(chat.lastResponseID == nil)
    }

    @Test func sortedMessagesUseCreationDate() {
        let chat = AIChat(title: "Sorted")
        let newer = ChatMessage(role: .assistant, content: "Second")
        newer.createdAt = Date(timeIntervalSince1970: 20)
        let older = ChatMessage(role: .user, content: "First")
        older.createdAt = Date(timeIntervalSince1970: 10)
        chat.messages = [newer, older]

        #expect(chat.sortedMessages.map(\.content) == ["First", "Second"])
        #expect(chat.lastMessage?.content == "Second")
    }

    @Test func messageTracksStreamingStatusAndResponseID() {
        let message = ChatMessage(role: .assistant, content: "")

        #expect(message.status == .completed)

        message.status = .streaming
        message.openAIResponseID = "resp_123"
        message.errorMessage = nil

        #expect(message.status == .streaming)
        #expect(message.openAIResponseID == "resp_123")
    }

    @Test func toolEventStatusChangesAndLinksToMessage() throws {
        let context = try makeContext()
        let chat = AIChat(title: "Tools")
        let message = ChatMessage(role: .assistant, content: "")
        let event = AIToolEvent(
            message: message,
            toolName: "canvas_create_sticky_note",
            status: .running,
            summary: "Creating sticky note"
        )
        chat.messages.append(message)
        message.chat = chat
        message.toolEvents.append(event)
        context.insert(chat)
        context.insert(message)
        context.insert(event)

        #expect(event.status == .running)
        #expect(message.toolEvents.count == 1)

        event.status = .completed
        event.completedAt = Date()

        #expect(event.status == .completed)
        #expect(event.completedAt != nil)
        #expect(event.message?.id == message.id)
    }

    @Test func sortedToolEventsUseCreationDate() {
        let message = ChatMessage(role: .assistant, content: "")
        let newer = AIToolEvent(toolName: "canvas_move_objects", status: .completed, summary: "Moved")
        newer.createdAt = Date(timeIntervalSince1970: 20)
        let older = AIToolEvent(toolName: "canvas_create_sticky_note", status: .completed, summary: "Created")
        older.createdAt = Date(timeIntervalSince1970: 10)
        message.toolEvents = [newer, older]

        #expect(message.sortedToolEvents.map(\.toolName) == [
            "canvas_create_sticky_note",
            "canvas_move_objects",
        ])
    }

    @Test func attachmentStatesStillReflectClipLifecycle() {
        let clip = Clip(content: "Attached", origin: .clipboard)
        let attachment = ChatAttachment(clip: clip)

        #expect(attachment.state == .live)

        clip.softDelete()
        #expect(attachment.state == .softDeleted)

        attachment.clip = nil
        #expect(attachment.state == .hardDeleted)
    }

    @Test func chatServiceCreatesChatForActiveWorkspace() throws {
        let context = try makeContext()
        let inactive = Workspace(name: "Inbox")
        let active = Workspace(name: "Board", isActive: true)
        context.insert(inactive)
        context.insert(active)

        let chat = AIChatService.createChat(in: context, workspaces: [inactive, active])

        #expect(chat.title == "New Chat")
        #expect(chat.workspace?.id == active.id)
        #expect(active.chats.contains { $0.id == chat.id })
        #expect((try context.fetch(FetchDescriptor<AIChat>())).count == 1)
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
