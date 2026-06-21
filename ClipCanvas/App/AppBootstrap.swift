import SwiftData
import Foundation

enum AppBootstrap {
    // App Intents run in their own process and need a container with the same schema
    // as the main app's — this is the single source of truth for that schema list.
    static func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(for: Clip.self, Workspace.self, CanvasObject.self,
                           ClipTag.self, AIChat.self, ChatMessage.self, ChatAttachment.self,
                           AIToolEvent.self)
    }

    static func ensureActiveWorkspace(in context: ModelContext) {
        TrashRetentionService.purgeExpired(in: context)
        PrivateClipRetentionService.purgeExpired(in: context)

        let all = (try? context.fetch(
            FetchDescriptor<Workspace>(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\Workspace.sortIndex)]
            )
        )) ?? []

        if all.isEmpty {
            context.insert(Workspace(name: "Canvas", sortIndex: 0, isActive: true))
        } else {
            let active = all.filter(\.isActive)
            if active.isEmpty {
                all[0].isActive = true
            } else if active.count > 1 {
                active.dropFirst().forEach { $0.isActive = false }
            }
        }

        seedBuiltInTags(in: context)
    }

    static func activeWorkspace(in context: ModelContext) -> Workspace? {
        let all = (try? context.fetch(
            FetchDescriptor<Workspace>(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\Workspace.sortIndex)]
            )
        )) ?? []
        return all.first(where: \.isActive) ?? all.first
    }

    private static func seedBuiltInTags(in context: ModelContext) {
        let existing = (try? context.fetch(
            FetchDescriptor<ClipTag>(predicate: #Predicate { $0.isBuiltIn == true })
        )) ?? []
        guard existing.isEmpty else { return }

        for def in ClipTag.builtInDefinitions {
            context.insert(ClipTag(name: def.name, colorHex: def.hex, isBuiltIn: true, sortIndex: def.sortIndex))
        }
    }
}
