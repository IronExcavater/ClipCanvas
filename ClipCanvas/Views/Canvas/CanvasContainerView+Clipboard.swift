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
    //
    // Skipped under the test runner: xcodebuild test launches this app as the unit
    // test host, so .onAppear still fires - reading the real pasteboard there pops
    // the OS-level "Allow Paste" alert with no automation to dismiss it, hanging the run.
    func checkClipboardOnForeground() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        importICloudClipboardIfNeeded()
        guard clipboardMonitoringEnabled else { return }
        guard let content = ClipboardService.readContent() else { return }
        defer { lastClipboardFingerprint = content.fingerprint }
        #if canImport(UIKit)
        // The OS "Allow Paste" alert fires as a side effect of the readContent() call
        // above. iOS keeps re-asking unless the user flips Settings -> ClipCanvas ->
        // Paste from Other Apps to Allow - that toggle only appears after the first ask,
        // so nudge the user toward it right after this first successful read.
        if !hasNudgedClipboardPermission {
            hasNudgedClipboardPermission = true
            showClipboardPermissionNudge = true
        }
        #endif
        guard content.fingerprint != lastClipboardFingerprint,
              !ClipboardService.wasRecentlyImported(content) else { return }
        captureClipboardContent(content)
        if iCloudClipboardSyncEnabled {
            ICloudClipboardService.publish(content)
        }
        importICloudClipboardIfNeeded()
    }

    func captureClipboardContent(_ content: ClipboardContent) {
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        showFeedback(
            isNew ? "Captured from clipboard" : "Clipboard already saved",
            kind: isNew ? .success : .info
        )
    }

    func importICloudClipboardIfNeeded() {
        guard iCloudClipboardSyncEnabled else { return }
        let lastSeen = lastSeenICloudClipboardTimestamp > 0
            ? Date(timeIntervalSince1970: lastSeenICloudClipboardTimestamp)
            : nil
        guard let latest = ICloudClipboardService.latestRemoteContent(after: lastSeen),
              !ClipboardService.wasRecentlyImported(latest.content) else { return }
        lastSeenICloudClipboardTimestamp = latest.date.timeIntervalSince1970
        captureClipboardContent(latest.content)
    }

    func copySelectedToClipboard() {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        guard !objects.isEmpty else { return }
        let clips = objects.compactMap(\.clip)
        if clips.count == objects.count {
            ClipActionService.copy(clips)
            if iCloudClipboardSyncEnabled, let first = clips.first {
                if first.type == .image, let data = first.imageData {
                    ICloudClipboardService.publish(.image(data, uti: first.imageUTI ?? "public.png"))
                } else {
                    ICloudClipboardService.publish(.text(clips.map(\.content).joined(separator: "\n\n")))
                }
            }
        } else {
            let text = objects.map(\.displayText).filter { !$0.isEmpty }.joined(separator: "\n\n")
            guard !text.isEmpty else { return }
            ClipboardService.writeString(text)
            if iCloudClipboardSyncEnabled {
                ICloudClipboardService.publish(.text(text))
            }
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
