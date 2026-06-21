import AppIntents

// Runs in its own process, so it can't reach the live canvas directly — it requests the
// paste via PendingCanvasActionStore and brings the app forward to perform it, same as the
// Home Screen quick action / Dock menu entry points.
struct CopyClipboardToCanvasIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Clipboard to Canvas"
    static let description = IntentDescription("Pastes the current clipboard contents into the active ClipCanvas workspace.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingCanvasActionStore.requestCopyToCanvas()
        return .result()
    }
}
