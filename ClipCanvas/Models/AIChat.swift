import Foundation
import SwiftData

enum ChatRole: String, Codable {
    case user
    case assistant
}

enum AttachmentState {
    case live        // clip is active
    case softDeleted // clip is in trash; can be restored
    case hardDeleted // clip is permanently gone; UI shows a deleted placeholder
}

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

@Model
final class ChatAttachment {
    var id: UUID = UUID()
    var message: ChatMessage?
    var clip: Clip?   // nullified on hard delete
    var createdAt: Date = Date()

    init(clip: Clip) {
        self.clip = clip
    }

    var state: AttachmentState {
        guard let clip else { return .hardDeleted }
        return clip.deletedAt != nil ? .softDeleted : .live
    }
}
