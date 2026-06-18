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
}
