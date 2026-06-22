import AppIntents

// AppShortcutsProvider registers Siri phrase patterns and Shortcuts app actions.
// The OS discovers these at compile time — no runtime registration needed.
struct ClipCanvasShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CopyClipboardToCanvasIntent(),
            phrases: [
                "Paste clipboard into \(.applicationName)",
                "Paste into canvas in \(.applicationName)"
            ],
            shortTitle: "Paste",
            systemImageName: "doc.on.clipboard"
        )
        AppShortcut(
            intent: AddTextToCanvasIntent(),
            phrases: [
                "Add text to \(.applicationName)",
                "Add to canvas in \(.applicationName)"
            ],
            shortTitle: "Add Text",
            systemImageName: "plus.rectangle.on.rectangle"
        )
    }
}
