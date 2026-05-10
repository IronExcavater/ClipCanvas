import AppIntents
import SwiftData

struct AddTextToCanvasIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Text to Canvas"
    static let description = IntentDescription(
        "Adds explicit text input to the active ClipCanvas workspace.",
        categoryName: "Canvas"
    )
    static let openAppWhenRun = true

    @Parameter(title: "Text", description: "Text to add to the active canvas")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "No text provided.")
        }

        let container = try AppBootstrap.makeModelContainer()
        let context = container.mainContext
        guard let workspace = AppBootstrap.activeWorkspace(in: context) else {
            return .result(dialog: "No active workspace.")
        }

        let snippet = Snippet.make(from: trimmed, capturedBy: .appIntent)
        context.insert(snippet)
        let card = WorkspaceCard(snippet: snippet, x: 160, y: 180)
        card.workspace = workspace
        workspace.cards.append(card)
        workspace.updatedAt = Date()
        try? context.save()

        return .result(dialog: "Added to canvas.")
    }
}
