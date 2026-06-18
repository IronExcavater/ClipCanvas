import Foundation
import SwiftData

enum AIChatService {
    static func createChat(in context: ModelContext, workspaces: [Workspace]) -> AIChat {
        let workspace = workspaces.first(where: \.isActive) ?? workspaces.first
        return createChat(in: context, workspace: workspace)
    }

    static func createChat(in context: ModelContext, workspace: Workspace?) -> AIChat {
        let title = workspace.map { "\($0.name) AI" } ?? "New Chat"
        let chat = AIChat(title: title)

        if let workspace {
            chat.workspace = workspace
            workspace.chats.append(chat)
        }

        context.insert(chat)
        return chat
    }

    @discardableResult
    static func attachObjects(
        _ objects: [CanvasObject],
        to chat: AIChat,
        in context: ModelContext,
        messageContent: String? = nil
    ) -> ChatMessage? {
        let uniqueObjects = uniqueLiveObjects(objects)
        guard !uniqueObjects.isEmpty else { return nil }

        let message = ChatMessage(
            role: .user,
            content: messageContent ?? ""
        )
        message.chat = chat
        chat.messages.append(message)
        context.insert(message)

        for object in uniqueObjects {
            let attachment = ChatAttachment(object: object)
            attachment.message = message
            message.attachments.append(attachment)
            context.insert(attachment)
        }

        if shouldReplacePlaceholderTitle(chat) {
            chat.title = defaultTitle(for: uniqueObjects)
        }
        chat.updatedAt = Date()
        return message
    }
}

private extension AIChatService {
    static func uniqueLiveObjects(_ objects: [CanvasObject]) -> [CanvasObject] {
        var seen = Set<UUID>()
        return objects.filter { object in
            guard object.isVisible, !seen.contains(object.id) else { return false }
            seen.insert(object.id)
            return true
        }
    }

    static func defaultTitle(for objects: [CanvasObject]) -> String {
        if objects.count == 1 {
            let preview = objects[0].displayText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !preview.isEmpty {
                return String(preview.prefix(42))
            }
        }
        return "\(objects.count) Canvas Cards"
    }

    static func shouldReplacePlaceholderTitle(_ chat: AIChat) -> Bool {
        if chat.title == "New Chat" { return true }
        guard let workspace = chat.workspace else { return false }
        return chat.title == "\(workspace.name) AI"
    }
}
