import Foundation
import SwiftData

struct ExpiryService {
    static func setExpiry(for snippet: Snippet) {
        let calendar = Calendar.current
        switch snippet.sensitivity {
        case .normal:
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
        let snippets = (try? context.fetch(FetchDescriptor<Snippet>())) ?? []
        for snippet in snippets where (snippet.expiresAt ?? .distantFuture) < now {
            context.delete(snippet)
        }
    }
}
