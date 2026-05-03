import Foundation
import SwiftData

@Model
final class WorkspaceChatThread {
    var id: UUID
    var title: String
    var workspace: Workspace?
    var relatedCardIDs: [UUID]
    var relatedTransformRunIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \WorkspaceChatMessage.thread) var messages: [WorkspaceChatMessage]

    init(
        title: String,
        workspace: Workspace?,
        relatedCardIDs: [UUID] = [],
        relatedTransformRunIDs: [UUID] = []
    ) {
        self.id = UUID()
        self.title = title
        self.workspace = workspace
        self.relatedCardIDs = relatedCardIDs
        self.relatedTransformRunIDs = relatedTransformRunIDs
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
    }

    var sortedMessages: [WorkspaceChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class WorkspaceChatMessage {
    var id: UUID
    var role: ChatRole
    var content: String
    var createdAt: Date
    var thread: WorkspaceChatThread?

    init(role: ChatRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}

enum ChatRole: String, Codable, CaseIterable {
    case user
    case reply
    case system
}
