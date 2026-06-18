import SwiftUI
import SwiftData

@main
struct ClipCanvasApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Clip.self, Workspace.self, CanvasObject.self,
                                      ClipTag.self, AIChat.self, ChatMessage.self, ChatAttachment.self,
                                      AIToolEvent.self)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
        .commands {
            ClipCanvasCommands()
        }
    }
}
