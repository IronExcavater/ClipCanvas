import AppIntents

struct CopyClipboardToCanvasIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Clipboard to Canvas"
    static let description = IntentDescription(
        "Opens ClipCanvas to copy the current clipboard into the active canvas.",
        categoryName: "Canvas"
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingCanvasActionStore.requestCopyToCanvas(method: .appIntent)
        NotificationCenter.default.post(name: .copyToCanvasRequested, object: CaptureMethod.appIntent)
        return .result()
    }
}
