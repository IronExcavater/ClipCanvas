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
                context.delete(workspace)
            }
        }
    }
}
