import AppIntents
import SwiftData

// Unlike the clipboard intent, this one carries its own payload, so it can do the SwiftData
// write directly rather than bouncing through PendingCanvasActionStore — it needs its own
// ModelContainer since this intent runs in a separate process from the main app.
struct AddTextToCanvasIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Text to Canvas"
    static let description = IntentDescription("Adds the given text as a new card in the active ClipCanvas workspace.")

    @Parameter(title: "Text")
    var text: String

    func perform() async throws -> some IntentResult {
        let container = try AppBootstrap.makeModelContainer()
        let context = ModelContext(container)

        guard let workspace = AppBootstrap.activeWorkspace(in: context) else {
            return .result()
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result() }

        let classification = ClipClassificationService.classifySensitivity(trimmed)
        let clip = Clip(
            content: trimmed,
            origin: .typed,
            sensitivity: classification.sensitivity,
            sensitivityReason: classification.reason
        )
        context.insert(clip)
        workspace.place(clip: clip, at: workspace.nextPosition())
        try context.save()

        return .result()
    }
}
