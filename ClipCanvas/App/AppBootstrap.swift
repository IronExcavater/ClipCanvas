import Foundation
import SwiftData

enum AppBootstrap {
    static let schema: [any PersistentModel.Type] = [
        Snippet.self,
        Workspace.self,
        WorkspaceCard.self,
        TransformRun.self
    ]

    static func makeModelContainer() throws -> ModelContainer {
        do {
            let schema = Schema(AppBootstrap.schema)
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            try resetDefaultStore()
            let schema = Schema(AppBootstrap.schema)
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        }
    }

    @MainActor
    static func ensureActiveWorkspace(in context: ModelContext) {
        let descriptor = FetchDescriptor<Workspace>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
        )
        let workspaces = (try? context.fetch(descriptor)) ?? []
        let activeWorkspaces = workspaces.filter(\.isActive)
        if let active = activeWorkspaces.first {
            for workspace in activeWorkspaces.dropFirst() {
                workspace.isActive = false
                workspace.updatedAt = Date()
            }
            active.updatedAt = Date()
            return
        }

        if let first = workspaces.first {
            first.isActive = true
            first.updatedAt = Date()
            return
        }

        let workspace = Workspace(name: "Canvas", sortIndex: 0, isActive: true)
        context.insert(workspace)
    }

    @MainActor
    static func activeWorkspace(in context: ModelContext) -> Workspace? {
        let activeDescriptor = FetchDescriptor<Workspace>(
            predicate: #Predicate { $0.isActive && !$0.isArchived },
            sortBy: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
        )
        if let active = (try? context.fetch(activeDescriptor))?.first {
            return active
        }
        ensureActiveWorkspace(in: context)
        return (try? context.fetch(activeDescriptor))?.first
    }

    private static func resetDefaultStore() throws {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let candidates = [
            "default.store",
            "default.store-shm",
            "default.store-wal"
        ]

        for file in candidates {
            let url = applicationSupport.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
