import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct AIChatModelTests {
    @Test func chatDefaultsToQuickModeAndUnpinned() {
        let chat = AIChat(title: "Workspace chat")

        #expect(chat.mode == .quick)
        #expect(!chat.isPinned)
        #expect(chat.deletedAt == nil)
        #expect(chat.openAIConversationID == nil)
        #expect(chat.lastResponseID == nil)
    }

    @Test func chatSupportsSoftDeleteAndRestore() {
        let chat = AIChat(title: "Draft")

        chat.softDelete()
        #expect(chat.deletedAt != nil)

        chat.restore()
        #expect(chat.deletedAt == nil)
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
        let context = try ModelContextFactory.makeContext()
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

    @Test func sortedAttachmentsUseCreationDate() {
        let message = ChatMessage(role: .user, content: "Attached")
        let newer = ChatAttachment(clip: Clip(content: "Second", origin: .clipboard))
        newer.createdAt = Date(timeIntervalSince1970: 20)
        let older = ChatAttachment(clip: Clip(content: "First", origin: .clipboard))
        older.createdAt = Date(timeIntervalSince1970: 10)
        message.attachments = [newer, older]

        #expect(message.sortedAttachments.map { $0.clip?.content } == ["First", "Second"])
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

    @Test func objectAttachmentStateReflectsObjectAndClipLifecycle() {
        let workspace = Workspace(name: "Board")
        let clip = Clip(content: "Attached", origin: .clipboard)
        let object = CanvasObject(kind: .clipNote, workspace: workspace, clip: clip, x: 0, y: 0, width: 220, height: 140)
        let attachment = ChatAttachment(object: object)

        #expect(attachment.state == .live)

        clip.softDelete()
        #expect(attachment.state == .softDeleted)

        clip.restore()
        object.softDelete()
        #expect(attachment.state == .softDeleted)
    }
}
