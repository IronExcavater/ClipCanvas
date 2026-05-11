import Foundation
import SwiftData

struct ExpiryService {
    static func setExpiry(for snippet: Snippet) {
        let calendar = Calendar.current
        switch snippet.sensitivity {
        case .normal:
            // @AppStorage / UserDefaults returns 0 when the key has never been written.
            // Treat that first-run state as the 30-day product default.
            let days = UserDefaults.standard.integer(forKey: "normalExpiryDays")
            snippet.expiresAt = days == -1 ? nil : calendar.date(byAdding: .day, value: days == 0 ? 30 : days, to: snippet.createdAt)
        case .sensitive:
            snippet.expiresAt = calendar.date(byAdding: .day, value: 1, to: snippet.createdAt)
        case .privateContent:
            snippet.expiresAt = calendar.date(byAdding: .hour, value: 1, to: snippet.createdAt)
        }
    }

    static func deleteExpired(in context: ModelContext) {
        let now = Date()

        // Only fetch snippets that have an expiry date — avoids loading the entire library.
        // #Predicate is evaluated by SwiftData as a SQL WHERE clause, so filtering happens
        // in the database rather than in memory.
        let descriptor = FetchDescriptor<Snippet>(predicate: #Predicate { $0.expiresAt != nil })
        let candidates = (try? context.fetch(descriptor)) ?? []
        for snippet in candidates where snippet.expiresAt! < now {
            context.delete(snippet)
        }

        // When a Snippet is deleted, its WorkspaceCards are set to nil (not cascade-deleted)
        // because the relationship runs Workspace → Card, not Snippet → Card.
        // Clean up any cards that are now orphaned so they don't show as blank on the canvas.
        let allCards = (try? context.fetch(FetchDescriptor<WorkspaceCard>())) ?? []
        for card in allCards where card.snippet == nil {
            context.delete(card)
        }
    }
}
