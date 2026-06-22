import SwiftUI
import SwiftData

extension CanvasContainerView {

    func paste() {
        guard clipboardAccessEnabled else {
            showFeedback("Clipboard is off", kind: .info)
            return
        }
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty", kind: .info)
            return
        }
        captureCanvasUndoSnapshot()
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        workspace.placeDuplicate(of: clip, at: workspace.nextPosition(around: visibleViewportCenter), in: context)
        showFeedback("Pasted", kind: .success)
    }

    // Text handed off from the Share Extension via PendingCanvasActionStore.
    func addSharedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let sharedWorkspace = ClipCanvasWorkspaceShare.importWorkspace(from: trimmed, in: context, existing: workspaces) {
            WorkspaceActionService.activate(sharedWorkspace, among: workspaces)
            showFeedback("Shared workspace added", kind: .success)
            return
        }
        captureCanvasUndoSnapshot()
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

    // A single check on launch/foreground rather than a continuous poll.
    // Pasteboard reads are gated behind the launch prompt so iOS permission UI
    // appears at startup instead of after an unrelated clipboard action.
    //
    // Skipped under the test runner: xcodebuild test launches this app as the unit
    // test host, so .onAppear still fires - reading the real pasteboard there pops
    // the OS-level "Allow Paste" alert with no automation to dismiss it, hanging the run.
    func checkClipboardOnForeground() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard clipboardAccessEnabled else { return }
        importICloudClipboardIfNeeded()
        guard clipboardMonitoringEnabled else { return }
        guard let content = ClipboardService.readContent() else { return }
        defer { lastClipboardFingerprint = content.fingerprint }
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
        guard clipboardAccessEnabled else { return }
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
        guard clipboardAccessEnabled else {
            showFeedback("Clipboard is off", kind: .info)
            return
        }
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        guard !objects.isEmpty else { return }
        let clips = objects.compactMap(\.clip)
        if clips.count == objects.count {
            guard ClipActionService.copy(clips) else {
                showFeedback("Clipboard is off", kind: .info)
                return
            }
            if iCloudClipboardSyncEnabled, let first = clips.first {
                if first.type == .image, let data = first.imageData {
                    ICloudClipboardService.publish(.image(data, uti: first.imageUTI ?? "public.png", name: first.imageName))
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
        guard clipboardAccessEnabled else {
            showFeedback("Clipboard is off", kind: .info)
            return
        }
        guard selectedObjectIDs.count == 1,
              let object = orderedCanvasObjects(matching: selectedObjectIDs).first else { return }
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty", kind: .info)
            return
        }
        switch content {
        case .text(let text):
            captureCanvasUndoSnapshot()
            if let clip = object.clip {
                let classification = ClipClassificationService.classifySensitivity(text)
                clip.content = text
                clip.updateDetectedType()
                clip.updateSensitivity(classification.sensitivity, reason: classification.reason)
                clip.updatedAt = Date()
            } else {
                object.text = text
            }
        case .image(let data, let uti, let name):
            guard let clip = object.clip else {
                showFeedback("Select a clip to paste an image into", kind: .info)
                return
            }
            captureCanvasUndoSnapshot()
            clip.imageData = data
            clip.imageUTI = uti
            clip.imageName = name
            clip.isTypeManuallySet = false
            if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clip.content = name
            }
            clip.type = .image
            clip.updatedAt = Date()
        }
        object.markUpdated()
        showFeedback("Pasted", kind: .success)
    }

    func prepareClipboardAccessOnLaunch() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        if !clipboardPermissionPromptShown {
            showClipboardPermissionPrompt = true
            return
        }
        guard clipboardAccessEnabled else { return }
        checkClipboardOnForeground()
    }

    func enableClipboardAccessFromLaunchPrompt() {
        clipboardPermissionPromptShown = true
        clipboardAccessEnabled = true
        showClipboardPermissionPrompt = false
        checkClipboardOnForeground()
    }

    func disableClipboardAccess() {
        clipboardPermissionPromptShown = true
        clipboardAccessEnabled = false
        showClipboardPermissionPrompt = false
        clipboardMonitoringEnabled = false
        iCloudClipboardSyncEnabled = false
    }
}
