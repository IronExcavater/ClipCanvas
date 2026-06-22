import CoreGraphics
import Foundation
import Testing
@testable import ClipCanvas

@Suite struct AIChatPromptBuilderTests {
    @Test func visibleCardsUseClickableAppLinks() {
        let workspace = Workspace(name: "Research")
        let card = workspace.createNote(
            centeredAt: CGPoint(x: 100, y: 100),
            size: CGSize(width: 220, height: 140),
            text: "Important note"
        )
        let chat = AIChat(title: "Question")
        chat.workspace = workspace
        let message = ChatMessage(role: .user, content: "What is visible?")
        message.chat = chat
        chat.messages.append(message)

        let input = AIChatPromptBuilder.input(for: message, chat: chat, workspace: workspace)

        #expect(input.contains("clipcanvas://workspace/\(workspace.id.uuidString)"))
        #expect(input.contains("clipcanvas://object/\(card.id.uuidString)"))
        #expect(input.contains("[Important note]"))
    }

    @Test func attachedCardsIncludeTheirContentInModelInput() {
        let workspace = Workspace(name: "Research")
        let card = workspace.createNote(
            centeredAt: CGPoint(x: 100, y: 100),
            size: CGSize(width: 220, height: 140),
            text: "Attached launch detail"
        )
        let chat = AIChat(title: "Question")
        chat.workspace = workspace
        let attachmentMessage = ChatMessage(role: .user, content: "")
        attachmentMessage.chat = chat
        chat.messages.append(attachmentMessage)
        let attachment = ChatAttachment(object: card)
        attachment.message = attachmentMessage
        attachmentMessage.attachments.append(attachment)
        let prompt = ChatMessage(role: .user, content: "What is attached?")
        prompt.chat = chat
        chat.messages.append(prompt)

        let input = AIChatPromptBuilder.input(for: prompt, chat: chat, workspace: workspace)

        #expect(input.contains("Attached context:"))
        #expect(input.contains("Attached canvas card, content: Attached launch detail"))
    }

    @Test func currentUserMessageAttachmentsAreIncludedInModelInput() {
        let workspace = Workspace(name: "Research")
        let card = workspace.createNote(
            centeredAt: CGPoint(x: 100, y: 100),
            size: CGSize(width: 220, height: 140),
            text: "Selected card detail"
        )
        let chat = AIChat(title: "Question")
        chat.workspace = workspace
        let prompt = ChatMessage(role: .user, content: "Use the selected card")
        prompt.chat = chat
        chat.messages.append(prompt)
        let attachment = ChatAttachment(object: card)
        attachment.message = prompt
        prompt.attachments.append(attachment)

        let input = AIChatPromptBuilder.input(for: prompt, chat: chat, workspace: workspace)

        #expect(input.contains("Attached canvas card, content: Selected card detail"))
        #expect(input.contains("User request:\nUse the selected card"))
    }

    @Test func attachedPrivateClipsDoNotExposeContentInModelInput() {
        let workspace = Workspace(name: "Research")
        let clip = Clip(
            content: "password: hunter2",
            origin: .clipboard,
            sensitivity: .privateContent,
            sensitivityReason: .passwordLike
        )
        let card = CanvasObject(
            kind: .clipNote,
            workspace: workspace,
            clip: clip,
            x: 0,
            y: 0,
            width: 220,
            height: 140
        )
        workspace.canvasObjects = [card]
        let chat = AIChat(title: "Question")
        chat.workspace = workspace
        let attachmentMessage = ChatMessage(role: .user, content: "")
        attachmentMessage.chat = chat
        chat.messages.append(attachmentMessage)
        let attachment = ChatAttachment(object: card)
        attachment.message = attachmentMessage
        attachmentMessage.attachments.append(attachment)
        let prompt = ChatMessage(role: .user, content: "What is attached?")
        prompt.chat = chat
        chat.messages.append(prompt)

        let input = AIChatPromptBuilder.input(for: prompt, chat: chat, workspace: workspace)

        #expect(input.contains("Attached canvas card, content: private"))
        #expect(!input.contains("hunter2"))
    }
}
