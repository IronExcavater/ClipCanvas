import Foundation
import SwiftData

enum PrivateClipRetentionPolicy {
    nonisolated static let defaultExpiryInterval: TimeInterval = 30 * 60

    nonisolated static func expiryDate(for sensitivity: Sensitivity, from date: Date) -> Date? {
        sensitivity == .privateContent ? date.addingTimeInterval(defaultExpiryInterval) : nil
    }

    nonisolated static func isExpired(_ clip: Clip, at date: Date = Date()) -> Bool {
        guard clip.sensitivity == .privateContent, let expiresAt = clip.expiresAt else { return false }
        return expiresAt <= date
    }
}

enum PrivateClipRetentionService {
    @discardableResult
    static func purgeExpired(in context: ModelContext, now: Date = Date()) -> Int {
        let clips = (try? context.fetch(
            FetchDescriptor<Clip>(predicate: #Predicate { $0.deletedAt == nil })
        )) ?? []
        return purgeExpired(clips, in: context, now: now)
    }

    @discardableResult
    static func purgeExpired(_ clips: [Clip], in context: ModelContext, now: Date = Date()) -> Int {
        var deletedCount = 0

        for clip in clips where PrivateClipRetentionPolicy.isExpired(clip, at: now) {
            Array(clip.canvasObjects).forEach { context.delete($0) }
            context.delete(clip)
            deletedCount += 1
        }

        return deletedCount
    }
}
