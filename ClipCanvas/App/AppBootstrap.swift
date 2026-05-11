import Foundation
import SwiftData

enum AppBootstrap {
    // All persistent model types must be listed here so SwiftData knows what to include in the schema.
    static let schema: [any PersistentModel.Type] = [
        Snippet.self,
        Workspace.self,
        WorkspaceCard.self,
        TransformRun.self,
        WorkspaceChatThread.self,
        WorkspaceChatMessage.self
    ]

    static func makeModelContainer() throws -> ModelContainer {
        // Attempt to open the existing store. If the SQLite file is corrupted
        // (e.g. after a crash), wipe it and start fresh rather than crashing.
        let schema = Schema(AppBootstrap.schema)
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            try resetDefaultStore()
            return try ModelContainer(for: schema, configurations: [config])
        }
    }

    // @MainActor ensures this runs on the main thread — SwiftData model context
    // operations must always happen on the thread that owns the context.
    @MainActor
    static func ensureActiveWorkspace(in context: ModelContext) {
        // FetchDescriptor is SwiftData's query builder — like a type-safe SQL SELECT.
        let descriptor = FetchDescriptor<Workspace>(
            predicate: #Predicate { !$0.isArchived },   // #Predicate is a compile-time checked filter
            sortBy: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
        )
        let workspaces = (try? context.fetch(descriptor)) ?? []
        let activeWorkspaces = workspaces.filter(\.isActive)    // keyPath shorthand, equivalent to { $0.isActive }

        if let active = activeWorkspaces.first {
            // Deactivate any duplicates — there should only ever be one active workspace.
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

        // No workspaces at all — create the default one.
        let workspace = Workspace(name: "Canvas", sortIndex: 0, isActive: true)
        context.insert(workspace)   // insert registers the object with SwiftData for persistence
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

    // Deletes the on-disk SQLite store files so a fresh database can be created.
    // Called only when the store fails to open (e.g. file corruption after a crash).
    private static func resetDefaultStore() throws {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let candidates = ["default.store", "default.store-shm", "default.store-wal"]
        for file in candidates {
            let url = applicationSupport.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
