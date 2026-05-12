# Clip Version History & Transform Foundation — Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans`. This is a focused reimplementation slice from `2026-05-12-clipcanvas-rewrite.md`, adapted to the current showcase branch.

**Goal:** Make clips support in-place version history so future AI transforms can mutate the existing clip instead of creating duplicate clips or cards. Add the model, tests, UI navigation in clip details, and a deterministic transform service stub that can later be backed by Foundation Models/OpenAI.

**Why next:** The current app already has first-class clips, sticky-note canvas placement, history, tags, and details. The biggest missing architectural piece from the rewrite plan is versioned clip content. Implementing this before AI keeps the data model stable and makes transform UI testable without network calls.

---

## Scope

In:
- Add `TransformKind` and `ClipVersion`.
- Store ordered versions on `Clip`.
- Add `applyVersion`, `navigateVersion`, and safe manual edit behavior.
- Show version navigation in `ClipDetailSheet`.
- Add a local `TransformService` stub with deterministic outputs for tests.
- Add context/detail actions for transform commands, but keep network AI out.

Out:
- OpenAI key handling.
- FoundationModels integration.
- Unified AI chat panel.
- Drawing/PencilKit.

---

## File Map

| Action | Path |
| --- | --- |
| Modify | `ClipCanvas/Models/Clip.swift` |
| Create | `ClipCanvas/Services/TransformService.swift` |
| Modify | `ClipCanvas/Views/Canvas/ClipDetailSheet.swift` |
| Modify | `ClipCanvas/Views/Common/ClipRowView.swift` |
| Modify | `ClipCanvas/Views/Canvas/ClipCard.swift` |
| Create | `ClipCanvasTests/ClipVersionTests.swift` |
| Create | `ClipCanvasTests/TransformServiceTests.swift` |

---

## Data Model

Add:

```swift
enum TransformKind: String, Codable, CaseIterable {
    case distill
    case actionItems
    case cleanUp
    case rewrite
    case title
}

struct ClipVersion: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var content: String
    var transformKind: TransformKind?
    var createdAt: Date = Date()
}
```

Add to `Clip`:
- `var versionsData: Data?`
- `var currentVersionIndex: Int = 0`
- computed `var versions: [ClipVersion]`
- `var hasVersionHistory: Bool`
- `func applyVersion(_ content: String, transform: TransformKind?)`
- `func navigateVersion(by delta: Int)`
- `func replaceCurrentContent(_ content: String)` for manual edits.

Keep `Clip.content` as the denormalized current value so existing queries, previews, clipboard writes, and search continue to work without a migration-heavy rewrite.

---

## Tasks

- [ ] **Task 1: Add failing version tests**
  - Verify a new clip has one original version.
  - Verify `applyVersion` appends and updates `content`.
  - Verify navigating back restores `content`.
  - Verify applying a new version after navigating back trims forward history.
  - Verify manual edit updates the current version and `content`.

- [ ] **Task 2: Implement version storage on `Clip`**
  - Encode/decode versions through `JSONEncoder`/`JSONDecoder`.
  - Lazily synthesize one original version for existing clips with no `versionsData`.
  - Keep `updatedAt` fresh on all mutations.
  - Keep type detection updated when content changes.

- [ ] **Task 3: Add deterministic `TransformService`**
  - `transform(_ kind:text:) async throws -> String`
  - `prompt(for:text:) -> String`
  - Local fallback behavior:
    - `title`: first meaningful line, max 60 chars.
    - `cleanUp`: trim whitespace and collapse excessive blank lines.
    - `actionItems`: bullet lines from sentence-like chunks.
    - `distill`: short summary-like first paragraph.
    - `rewrite`: plain readable rewrite placeholder.

- [ ] **Task 4: Add clip detail version UI**
  - Show version count and current index only when `hasVersionHistory`.
  - Add previous/next icon buttons.
  - Show transform kind metadata for transformed versions.
  - Make Done use `replaceCurrentContent` instead of mutating `clip.content` directly.
  - Add transform action strip in the detail sheet.

- [ ] **Task 5: Add lightweight canvas/list affordances**
  - Show a small `v2` badge on `ClipCard` and `ClipRowView` when history exists.
  - Add context menu transform actions where a clip row already has context options.
  - Avoid menus on canvas cards if UIKit reparenting warnings return.

- [ ] **Task 6: Verify**
  - Run `xcodebuild test -project ClipCanvas.xcodeproj -scheme ClipCanvas -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ClipCanvasTests/ClipVersionTests`.
  - Run `xcodebuild test -project ClipCanvas.xcodeproj -scheme ClipCanvas -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ClipCanvasTests/TransformServiceTests`.
  - Run full build.

---

## Commit Plan

1. `feat: add clip version history`
2. `feat: add transform service stubs`
3. `feat: show clip version controls`
