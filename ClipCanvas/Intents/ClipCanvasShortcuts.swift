import AppIntents

struct ClipCanvasShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CopyClipboardToCanvasIntent(),
            phrases: [
                "Copy clipboard to \(.applicationName)",
                "Copy to canvas in \(.applicationName)"
            ],
            shortTitle: "Copy to Canvas",
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
