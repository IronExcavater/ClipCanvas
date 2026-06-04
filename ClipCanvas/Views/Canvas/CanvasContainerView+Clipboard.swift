import SwiftUI
import SwiftData

extension CanvasContainerView {

    func paste() {
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        workspace.place(clip: clip, at: workspace.nextPosition(around: visibleViewportCenter))
        showFeedback("Pasted")
    }

    func startClipboardListening() {
        guard clipboardWatcherTask == nil else { return }
        if let content = ClipboardService.readContent(),
           content.fingerprint != lastClipboardFingerprint,
           !ClipboardService.wasRecentlyImported(content) {
            captureClipboardContent(content)
        }
        lastClipboardFingerprint = ClipboardService.readContent()?.fingerprint
        clipboardWatcherTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled, let content = ClipboardService.readContent() else { continue }
                guard content.fingerprint != lastClipboardFingerprint else { continue }
                lastClipboardFingerprint = content.fingerprint
                guard !ClipboardService.wasRecentlyImported(content) else { continue }
                captureClipboardContent(content)
            }
        }
    }

    func stopClipboardListening() {
        clipboardWatcherTask?.cancel()
        clipboardWatcherTask = nil
    }

    func captureClipboardContent(_ content: ClipboardContent) {
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        showFeedback(isNew ? "Captured from clipboard" : "Clipboard already saved")
    }
}
