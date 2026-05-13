# Sensitive Content and System Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Protect password/private clips with automatic expiry and masking while expanding system-wide capture through App Store-safe iOS/iPadOS extension flows and a macOS helper for true always-on clipboard monitoring.

**Architecture:** Extend the existing `ClipClassificationService` and `Sensitivity.privateContent` behavior with persisted expiry metadata and transient reveal state. Add a shared external capture queue so foreground paste, Share Extension, Action Extension, App Intents, Shortcuts, and the macOS helper all import through one deduplicated pipeline. Do not use private iOS APIs or promise always-running iOS clipboard monitoring.

**Tech Stack:** SwiftData, SwiftUI, LocalAuthentication, UIKit/AppKit pasteboard APIs, App Groups, Share Extension, Action Extension, App Intents, App Shortcuts, macOS menu-bar helper.

---

## Product Policy

- Private/password-like clips are useful but should not stay visible or permanent by default.
- Default private content retention is 30 minutes.
- Private content is masked in canvas, lists, details, search previews, chat attachments, and AI context.
- Reveal is temporary and local to the UI session.
- AI does not receive private clip bodies unless the user explicitly reveals and attaches the clip for that chat turn.
- iOS/iPadOS capture must use public extension/intent mechanisms. True always-on clipboard capture is macOS-only.

## Clip Model Changes

Extend `Clip`:

```swift
var expiresAt: Date?
var sensitivityReasonRaw: String?
var lastRevealedAt: Date?
```

Add:

```swift
enum SensitivityReason: String, Codable, CaseIterable {
    case passwordLike
    case secretKeyword
    case creditCard
    case ssn
    case email
    case userMarkedPrivate
}
```

`lastRevealedAt` may be omitted from persistence if reveal state is implemented in a transient `PrivateClipRevealStore`. Prefer transient reveal state so relaunch masks content again.

## Expiry Rules

Defaults:

- `.normal`: no expiry.
- `.sensitive`: no automatic deletion by default, but masked if user enables strict privacy later.
- `.privateContent`: expires in 30 minutes.
- User-marked private clips use the same default as `.privateContent`.

Purge triggers:

- App launch through `AppBootstrap.ensureActiveWorkspace(in:)`.
- Foreground activation.
- Foreground periodic timer every 60 seconds.
- macOS helper import cycle.
- Manual "Purge expired private clips" setting action.

Soft delete vs hard delete:

- Expired private clips should be hard deleted by default because retention defeats the privacy goal.
- If a clip has canvas objects, delete or nullify those objects according to the visual workspace model's object deletion policy.

## Mask and Reveal UI

Views to update:

- `ClipCard`
- `ClipRowView`
- `ClipDetailSheet`
- `ChatMessageBubble`/chat attachment chips
- Recently Deleted rows
- Search result snippets

Mask format:

- Single-line preview: `••••••••`
- Multi-line/detail preview: fixed-height masked text block.
- Image private content: blurred thumbnail with lock icon.

Reveal control:

- Eye icon appears on private masked clips.
- Tap reveal requests LocalAuthentication when setting is enabled and device supports it.
- Reveal duration: 60 seconds per clip per surface.
- Eye-slash hides immediately.

Settings:

- Private clip expiry: 15 minutes, 30 minutes, 1 hour, Never.
- Require Face ID/Touch ID to reveal: on by default.
- Include revealed private clips in AI context for one turn only: off by default and shown as a per-chat-turn confirmation.

## External Capture Queue

Create a shared App Group queue:

```swift
enum ExternalCaptureSource: String, Codable {
    case foregroundPaste
    case shareExtension
    case actionExtension
    case appIntent
    case shortcut
    case macPasteboardHelper
}

enum ExternalCaptureIntent: String, Codable {
    case saveToHistory
    case createStickyNote
    case askAI
}

struct ExternalCaptureRequest: Codable, Identifiable {
    var id: UUID
    var source: ExternalCaptureSource
    var intent: ExternalCaptureIntent
    var text: String?
    var imageData: Data?
    var uti: String?
    var createdAt: Date
}
```

All imports flow through `ExternalCaptureImportService`, which calls `Clip.findOrMake(from:origin:in:)` and then optionally creates a canvas object or chat attachment.

## iOS/iPadOS Capture

Supported mechanisms:

- Foreground/on-launch pasteboard import.
- Share Extension for text, URLs, and images.
- Action Extension for selected content where host apps provide it.
- App Intents and App Shortcuts for "Import Clipboard", "Create Sticky Note", and "Ask ClipCanvas AI".
- Shortcuts automations that pass clipboard text to the App Intent.

Explicit non-goal:

- Do not implement private or unreliable always-running iOS clipboard listeners.
- Do not rely on background modes that are unrelated to clipboard monitoring.

## macOS Capture

Add a lightweight menu-bar helper target:

- Monitors `NSPasteboard.general.changeCount`.
- Deduplicates by normalized content fingerprint.
- Writes `ExternalCaptureRequest` items into the App Group queue.
- Shows a menu with Pause Capture, Open ClipCanvas, Capture Current Clipboard, and Quit Helper.
- Launches at login only after user enables the setting.

The helper can grow into a local MCP server in a separate plan; v1 only writes capture requests.

## Ask ClipCanvas AI Action

Flow:

1. User selects text or shares content to "Ask ClipCanvas AI".
2. Extension/intent writes `ExternalCaptureRequest(intent: .askAI)`.
3. Main app imports or reuses the clip.
4. Main app opens or creates an `AIChat`.
5. The imported clip is attached to the chat.
6. Chat input is focused with suggested prompt text.

If the app is not running, the extension opens the app with a URL/deep-link containing the request ID.

## Implementation Tasks

### Task 1: Sensitive Clip Expiry Model

**Files:**
- Modify: `ClipCanvas/Models/Clip.swift`
- Modify: `ClipCanvas/Services/ClipClassificationService.swift`
- Test: `ClipCanvasTests/SensitiveClipExpiryTests.swift`

- [ ] Add expiry and reason fields to `Clip`.
- [ ] Add `SensitivityReason`.
- [ ] Update clip creation so password-like/private clips get default expiry.
- [ ] Test standalone passwords, labeled passwords, API keys, bearer tokens, and false positives.

### Task 2: Purge and Reveal Services

**Files:**
- Create: `ClipCanvas/Services/PrivateClipRetentionService.swift`
- Create: `ClipCanvas/Services/PrivateClipRevealStore.swift`
- Test: `ClipCanvasTests/PrivateClipRetentionTests.swift`

- [ ] Hard delete expired private clips.
- [ ] Provide transient reveal state by clip ID.
- [ ] Auto-hide revealed clips after 60 seconds.
- [ ] Add LocalAuthentication wrapper with injectable test double.

### Task 3: Mask Private Content Everywhere

**Files:**
- Modify: `ClipCanvas/Views/Canvas/ClipCard.swift`
- Modify: `ClipCanvas/Views/Common/ClipRowView.swift`
- Modify: `ClipCanvas/Views/Canvas/ClipDetailSheet.swift`
- Modify: `ClipCanvas/Views/Trash/TrashPage.swift`

- [ ] Add shared `PrivateClipContentView`.
- [ ] Add eye/eye-slash reveal controls.
- [ ] Ensure masked text does not leak through accessibility labels.
- [ ] Ensure details view starts masked after app relaunch.

### Task 4: AI Private Content Policy

**Files:**
- Modify: `ClipCanvas/Services/AIContextPacker.swift`
- Test: `ClipCanvasTests/AIContextPackerPrivateContentTests.swift`

- [ ] Exclude private clip bodies by default.
- [ ] Include private content only when a one-turn explicit attachment flag is set.
- [ ] Add context metadata that says private content was omitted.

### Task 5: External Capture Queue

**Files:**
- Create: `ClipCanvas/Services/ExternalCaptureQueue.swift`
- Create: `ClipCanvas/Services/ExternalCaptureImportService.swift`
- Test: `ClipCanvasTests/ExternalCaptureImportTests.swift`

- [ ] Store capture requests in an App Group JSON queue.
- [ ] Import queued text, URL, and image items.
- [ ] Reuse existing clips through current deduplication logic.
- [ ] Support intents: save to history, create sticky note, ask AI.

### Task 6: Share and Action Extensions

**Files:**
- Create target: `ClipCanvasShareExtension`
- Create target: `ClipCanvasActionExtension`
- Create shared files under `ClipCanvasExtensions/`

- [ ] Share extension accepts text, URLs, and images.
- [ ] Action extension accepts selected text where host apps provide it.
- [ ] Both write `ExternalCaptureRequest` to App Group.
- [ ] Both deep-link into the main app for `askAI`.

### Task 7: App Intents and Shortcuts

**Files:**
- Create: `ClipCanvas/AppIntents/ImportClipboardIntent.swift`
- Create: `ClipCanvas/AppIntents/CreateStickyNoteIntent.swift`
- Create: `ClipCanvas/AppIntents/AskClipCanvasAIIntent.swift`
- Create: `ClipCanvas/AppIntents/ClipCanvasShortcutsProvider.swift`

- [ ] Add Import Clipboard.
- [ ] Add Create Sticky Note.
- [ ] Add Ask ClipCanvas AI.
- [ ] Use `ForegroundContinuableIntent` where the chat UI must open.
- [ ] Route all writes through `ExternalCaptureImportService` or `WorkspaceActionRegistry`.

### Task 8: macOS Pasteboard Helper

**Files:**
- Create target: `ClipCanvasPasteboardHelper`
- Create: `ClipCanvasPasteboardHelper/PasteboardMonitor.swift`
- Create: `ClipCanvasPasteboardHelper/MenuBarApp.swift`

- [ ] Monitor `NSPasteboard.general.changeCount`.
- [ ] Deduplicate by fingerprint.
- [ ] Write queue requests to App Group.
- [ ] Add Pause Capture and Capture Current Clipboard menu actions.
- [ ] Add setting in main app to enable launch at login.

## Acceptance Criteria

- Password-like clips are masked and expire after 30 minutes by default.
- Reveal state is temporary and does not persist across relaunch.
- AI context excludes private clip bodies unless explicitly allowed for one turn.
- Share/Action/App Intent imports deduplicate through the same service as foreground paste.
- "Ask ClipCanvas AI" imports content and opens a chat with the clip attached.
- macOS helper captures clipboard while main app is closed.
- iOS/iPadOS plan does not depend on private background clipboard monitoring.

## Commit Plan

1. `feat: add private clip expiry`
2. `feat: mask and reveal private clips`
3. `feat: add external capture queue`
4. `feat: add share and action capture extensions`
5. `feat: add clipcanvas app intents`
6. `feat: add mac pasteboard helper`

## References

- UIPasteboard: https://developer.apple.com/documentation/uikit/uipasteboard
- UIPasteboard change notification: https://developer.apple.com/documentation/uikit/uipasteboard/changednotification
- App Intents: https://developer.apple.com/documentation/AppIntents/app-intents
- App Shortcuts: https://developer.apple.com/documentation/appintents/app-shortcuts
- Action extensions: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Action.html
- Share extensions: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html
- Background execution modes: https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
