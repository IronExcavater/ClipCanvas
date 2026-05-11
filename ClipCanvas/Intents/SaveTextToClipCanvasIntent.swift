import AppIntents
import SwiftData

// AppIntent subtype that accepts a text parameter from the user via Siri or the Shortcuts app.
struct AddTextToCanvasIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Text to Canvas"
    static let description = IntentDescription(
        "Adds explicit text input to the active ClipCanvas workspace.",
        categoryName: "Canvas"
    )
    // openAppWhenRun = true brings ClipCanvas to the foreground after the intent runs.
    static let openAppWhenRun = true

    // @Parameter declares a user-facing input — Siri prompts the user for this value.
    @Parameter(title: "Text", description: "Text to add to the active canvas")
    var text: String

    // @MainActor ensures this runs on the main thread, required for SwiftData operations.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "No text provided.")
        }

        // App Intents run in a separate process, so they must create their own ModelContainer
        // rather than sharing the one in the main app process.
        let container = try AppBootstrap.makeModelContainer()
        let context = container.mainContext
        guard let workspace = AppBootstrap.activeWorkspace(in: context) else {
            return .result(dialog: "No active workspace.")
        }

        let snippet = Snippet.make(from: trimmed, capturedBy: .appIntent)
        context.insert(snippet)
        workspace.addCard(snippet: snippet, x: 160, y: 180)
        // Explicit save needed in intents — the main app saves automatically on scene deactivation.
        try? context.save()

        return .result(dialog: "Added to canvas.")
    }
}
