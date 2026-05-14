import Foundation
import SwiftData

nonisolated enum ChatRole: String, Codable {
    case user
    case assistant
}

nonisolated enum AIChatMode: String, Codable, CaseIterable {
    case quick
    case thinking
}

nonisolated enum ChatMessageStatus: String, Codable, CaseIterable {
    case pending
    case streaming
    case completed
    case failed
    case cancelled
}

nonisolated enum AIToolEventStatus: String, Codable, CaseIterable {
    case queued
    case running
    case needsConfirmation
    case completed
    case failed
}

nonisolated enum AttachmentState {
    case live        // clip is active
    case softDeleted // clip is in trash; can be restored
    case hardDeleted // clip is permanently gone; UI shows a deleted placeholder
}

@Model
final class AIChat {
    var id: UUID = UUID()
    var title: String
    var modeRaw: String = AIChatMode.quick.rawValue
    var openAIConversationID: String?
    var lastResponseID: String?
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var workspace: Workspace?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
    var messages: [ChatMessage] = []

    init(title: String) {
        self.title = title
    }

    var lastMessage: ChatMessage? {
        sortedMessages.last
    }

    var preview: String {
        lastMessage?.content.components(separatedBy: .newlines).first ?? "No messages"
    }

    var mode: AIChatMode {
        get { AIChatMode(rawValue: modeRaw) ?? .quick }
        set { modeRaw = newValue.rawValue }
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var role: ChatRole
    var content: String
    var statusRaw: String = ChatMessageStatus.completed.rawValue
    var errorMessage: String?
    var openAIResponseID: String?
    var createdAt: Date = Date()

    var chat: AIChat?

    @Relationship(deleteRule: .cascade, inverse: \ChatAttachment.message)
    var attachments: [ChatAttachment] = []

    @Relationship(deleteRule: .cascade, inverse: \AIToolEvent.message)
    var toolEvents: [AIToolEvent] = []

    init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }

    var status: ChatMessageStatus {
        get { ChatMessageStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    var sortedAttachments: [ChatAttachment] {
        attachments.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var sortedToolEvents: [AIToolEvent] {
        toolEvents.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

@Model
final class ChatAttachment {
    var id: UUID = UUID()
    var message: ChatMessage?
    var canvasObject: CanvasObject?
    var clip: Clip?   // nullified on hard delete
    var createdAt: Date = Date()

    init(clip: Clip) {
        self.clip = clip
    }

    init(object: CanvasObject) {
        self.canvasObject = object
        self.clip = object.clip
    }

    var state: AttachmentState {
        if let canvasObject {
            guard canvasObject.deletedAt == nil else { return .softDeleted }
            if let clip = canvasObject.clip {
                return clip.deletedAt != nil ? .softDeleted : .live
            }
            return .live
        }
        guard let clip else { return .hardDeleted }
        return clip.deletedAt != nil ? .softDeleted : .live
    }
}

@Model
final class AIToolEvent {
    var id: UUID = UUID()
    var message: ChatMessage?
    var toolName: String
    var statusRaw: String
    var summary: String
    var argumentsData: Data?
    var resultData: Data?
    var createdAt: Date = Date()
    var completedAt: Date?

    init(
        message: ChatMessage? = nil,
        toolName: String,
        status: AIToolEventStatus,
        summary: String,
        argumentsData: Data? = nil,
        resultData: Data? = nil
    ) {
        self.message = message
        self.toolName = toolName
        self.statusRaw = status.rawValue
        self.summary = summary
        self.argumentsData = argumentsData
        self.resultData = resultData
    }

    var status: AIToolEventStatus {
        get { AIToolEventStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }
}
