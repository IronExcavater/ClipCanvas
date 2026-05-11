import AppIntents

// AppIntent is the protocol for Siri and Shortcuts actions. The OS calls perform()
// when the user triggers the shortcut by voice or from the Shortcuts app.
struct CopyClipboardToCanvasIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Clipboard to Canvas"
    static let description = IntentDescription(
        "Opens ClipCanvas to copy the current clipboard into the active canvas.",
        categoryName: "Canvas"
    )
    // openAppWhenRun = true brings the app to the foreground so the user can see the result.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Store the request in UserDefaults so it survives the app launch if needed.
        PendingCanvasActionStore.requestCopyToCanvas(method: .appIntent)
        // Also post a notification in case the app is already running.
        NotificationCenter.default.post(name: .copyToCanvasRequested, object: CaptureMethod.appIntent)
        return .result()
    }
}
