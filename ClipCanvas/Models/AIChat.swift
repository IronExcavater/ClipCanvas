import Foundation
import SwiftData

enum ChatRole: String, Codable {
    case user
    case assistant
}

// A chat session scoped to one workspace. Chats cascade-delete with their workspace.
@Model
final class AIChat {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var workspace: Workspace?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
    var messages: [ChatMessage] = []

    init(title: String) {
        self.title = title
    }

    var lastMessage: ChatMessage? {
        messages.max { $0.createdAt < $1.createdAt }
    }

    var preview: String {
        lastMessage?.content.components(separatedBy: .newlines).first ?? "No messages"
    }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var role: ChatRole
    var content: String
    var createdAt: Date = Date()

    var chat: AIChat?

    @Relationship(deleteRule: .cascade, inverse: \ChatAttachment.message)
    var attachments: [ChatAttachment] = []

    init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
}

// Attaches a clip to a message. When the clip is deleted, `clip` is nullified but
// the snapshots (content, image, type, color) are kept so chat history stays readable.
// The user can tap the attachment to see the snapshot in an overlay, or restore the clip.
@Model
final class ChatAttachment {
    var id: UUID = UUID()
    var message: ChatMessage?

    // Live reference — nullified if clip is deleted
    var clip: Clip?

    // Preserved snapshots
    var contentSnapshot: String
    var imageDataSnapshot: Data?
    var typeSnapshot: ClipType
    var colorSnapshot: CardColor
    var createdAt: Date = Date()

    init(from clip: Clip) {
        self.clip = clip
        self.contentSnapshot = clip.content
        self.imageDataSnapshot = clip.imageData
        self.typeSnapshot = clip.type
        self.colorSnapshot = clip.color
    }

    var isDeleted: Bool { clip == nil }
}
