import Foundation
import SwiftData

enum TrashRetentionService {
    static let defaultRetentionDays = 30
    private static let retentionKey = "settings.trashRetentionDays"

    static var configuredRetentionDays: Int {
        let value = UserDefaults.standard.integer(forKey: retentionKey)
        return value == 0 ? defaultRetentionDays : value
    }

    static func purgeExpired(in context: ModelContext, retentionDays: Int = configuredRetentionDays, now: Date = Date()) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else { return }

        let clips = (try? context.fetch(FetchDescriptor<Clip>())) ?? []
        for clip in clips {
            if let deletedAt = clip.deletedAt, deletedAt < cutoff {
                context.delete(clip)
            }
        }

        let workspaces = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        for workspace in workspaces {
            if let deletedAt = workspace.deletedAt, deletedAt < cutoff {
                deleteForever(workspace, in: context)
            }
        }

        let chats = (try? context.fetch(FetchDescriptor<AIChat>())) ?? []
        for chat in chats {
            if let deletedAt = chat.deletedAt, deletedAt < cutoff {
                context.delete(chat)
            }
        }
    }

    static func deleteForever(_ workspace: Workspace, in context: ModelContext) {
        deleteChats(for: workspace, in: context)

        let workspaceID = workspace.id
        let objects = ((try? context.fetch(FetchDescriptor<CanvasObject>())) ?? [])
            .filter { $0.workspace?.id == workspaceID }
        objects.forEach { context.delete($0) }

        context.delete(workspace)
    }

    private static func deleteChats(for workspace: Workspace, in context: ModelContext) {
        let workspaceID = workspace.id
        let chats = ((try? context.fetch(FetchDescriptor<AIChat>())) ?? [])
            .filter { $0.workspace?.id == workspaceID }
        let chatIDs = Set(chats.map(\.id))

        let messages = ((try? context.fetch(FetchDescriptor<ChatMessage>())) ?? [])
            .filter { message in
                guard let chatID = message.chat?.id else { return false }
                return chatIDs.contains(chatID)
            }
        let messageIDs = Set(messages.map(\.id))

        ((try? context.fetch(FetchDescriptor<ChatAttachment>())) ?? [])
            .filter { attachment in
                guard let messageID = attachment.message?.id else { return false }
                return messageIDs.contains(messageID)
            }
            .forEach { context.delete($0) }

        ((try? context.fetch(FetchDescriptor<AIToolEvent>())) ?? [])
            .filter { event in
                guard let messageID = event.message?.id else { return false }
                return messageIDs.contains(messageID)
            }
            .forEach { context.delete($0) }

        messages.forEach { context.delete($0) }
        chats.forEach { context.delete($0) }
    }
}
