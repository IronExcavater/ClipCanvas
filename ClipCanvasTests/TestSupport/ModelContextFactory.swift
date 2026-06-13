import SwiftData
@testable import ClipCanvas

enum ModelContextFactory {
    static func makeContext() throws -> ModelContext {
        try makeContext(for: [
            Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self,
            AIChat.self, ChatMessage.self, ChatAttachment.self, AIToolEvent.self,
        ])
    }

    static func makeCoreContext() throws -> ModelContext {
        try makeContext(for: [Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self])
    }

    private static func makeContext(for types: [any PersistentModel.Type]) throws -> ModelContext {
        let container = try ModelContainer(for: Schema(types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }
}
