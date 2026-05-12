import SwiftData
import Foundation

enum AppBootstrap {
    // Ensures at least one workspace exists and exactly one is active.
    // Call once at app launch from the SwiftData context.
    static func ensureActiveWorkspace(in context: ModelContext) {
        let all = (try? context.fetch(
            FetchDescriptor<Workspace>(sortBy: [SortDescriptor(\Workspace.sortIndex)])
        )) ?? []

        if all.isEmpty {
            let ws = Workspace(name: "Canvas", sortIndex: 0, isActive: true)
            context.insert(ws)
            return
        }

        let active = all.filter(\.isActive)
        if active.isEmpty {
            all[0].isActive = true
        } else if active.count > 1 {
            // Repair state: keep only the first active
            for ws in active.dropFirst() { ws.isActive = false }
        }
    }
}
