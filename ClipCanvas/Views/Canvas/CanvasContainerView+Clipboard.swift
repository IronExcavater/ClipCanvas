import SwiftUI
import SwiftData

extension CanvasContainerView {

    func paste() {
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty", kind: .info)
            return
        }
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        workspace.place(clip: clip, at: workspace.nextPosition(around: visibleViewportCenter))
        showFeedback("Pasted", kind: .success)
    }

    // Text handed off from the Share Extension via PendingCanvasActionStore.
    func addSharedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let classification = ClipClassificationService.classifySensitivity(trimmed)
        let clip = Clip(
            content: trimmed,
            origin: .shared,
            sensitivity: classification.sensitivity,
            sensitivityReason: classification.reason
        )
        context.insert(clip)
        workspace.place(clip: clip, at: workspace.nextPosition(around: visibleViewportCenter))
        showFeedback("Added from share", kind: .success)
    }

    // A single check on launch/foreground rather than a continuous poll - polling the
    // pasteboard in the background triggers the system "Allow Paste" prompt on every
    // change, which is what the clipboard-monitoring toggle exists to avoid.
    func checkClipboardOnForeground() {
        guard clipboardMonitoringEnabled else { return }
        guard let content = ClipboardService.readContent() else { return }
        defer { lastClipboardFingerprint = content.fingerprint }
        guard content.fingerprint != lastClipboardFingerprint,
              !ClipboardService.wasRecentlyImported(content) else { return }
        captureClipboardContent(content)
    }

    func captureClipboardContent(_ content: ClipboardContent) {
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        showFeedback(
            isNew ? "Captured from clipboard" : "Clipboard already saved",
            kind: isNew ? .success : .info
        )
    }

    func copySelectedToClipboard() {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        guard !objects.isEmpty else { return }
        let clips = objects.compactMap(\.clip)
        if clips.count == objects.count {
            ClipActionService.copy(clips)
        } else {
            let text = objects.map(\.displayText).filter { !$0.isEmpty }.joined(separator: "\n\n")
            guard !text.isEmpty else { return }
            ClipboardService.writeString(text)
        }
        showFeedback(objects.count == 1 ? "Copied" : "Copied \(objects.count) items", kind: .success)
    }

    func pasteClipboardIntoSelected() {
        guard selectedObjectIDs.count == 1,
              let object = orderedCanvasObjects(matching: selectedObjectIDs).first else { return }
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty", kind: .info)
            return
        }
        switch content {
        case .text(let text):
            if let clip = object.clip {
                let classification = ClipClassificationService.classifySensitivity(text)
                clip.content = text
                clip.type = Clip.detect(content: text, imageData: clip.imageData)
                clip.updateSensitivity(classification.sensitivity, reason: classification.reason)
                clip.updatedAt = Date()
            } else {
                object.text = text
            }
        case .image(let data, let uti):
            guard let clip = object.clip else {
                showFeedback("Select a clip to paste an image into", kind: .info)
                return
            }
            clip.imageData = data
            clip.imageUTI = uti
            clip.type = .image
            clip.updatedAt = Date()
        }
        object.markUpdated()
        showFeedback("Pasted", kind: .success)
    }
}
