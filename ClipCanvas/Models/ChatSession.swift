import Foundation
import SwiftData

// @Model marks this class for SwiftData persistence.
@Model
final class WorkspaceChatThread {
    var id: UUID
    var title: String
    var workspace: Workspace?           // parent; nil if the workspace was deleted
    var relatedCardIDs: [UUID]          // IDs of cards that provided context for this thread
    var relatedTransformRunIDs: [UUID]  // IDs of transform runs referenced in this thread
    var createdAt: Date
    var updatedAt: Date
    // Cascade delete: removing this thread also removes all its messages from the database.
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

    // Messages are stored unordered by SwiftData — sort by creation time when needed.
    var sortedMessages: [WorkspaceChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

// @Model marks this class for SwiftData persistence.
@Model
final class WorkspaceChatMessage {
    var id: UUID
    var role: ChatRole
    var content: String
    var createdAt: Date
    var thread: WorkspaceChatThread?    // parent thread; nil if thread was deleted

    init(role: ChatRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}

enum ChatRole: String, Codable, CaseIterable {
    case user    // sent by the person using the app
    case reply   // the model's response
    case system  // internal context message, hidden from the UI
}
