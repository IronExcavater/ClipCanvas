import SwiftData

enum AIChatService {
    static func createChat(in context: ModelContext, workspaces: [Workspace]) -> AIChat {
        let chat = AIChat(title: "New Chat")

        if let workspace = workspaces.first(where: \.isActive) ?? workspaces.first {
            chat.workspace = workspace
            workspace.chats.append(chat)
        }

        context.insert(chat)
        return chat
    }
}
