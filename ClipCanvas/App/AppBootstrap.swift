import SwiftData
import Foundation

enum AppBootstrap {
    static func ensureActiveWorkspace(in context: ModelContext) {
        TrashRetentionService.purgeExpired(in: context)

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
