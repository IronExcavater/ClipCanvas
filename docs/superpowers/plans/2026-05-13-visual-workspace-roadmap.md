# Visual Workspace Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reframe ClipCanvas from a clipboard canvas into a visual thinking workspace where clipboard history is one capture input and the canvas supports sticky notes, diagrams, drawings, connections, images, and AI-assisted organization.

**Architecture:** Add a canvas-facing `CanvasObject` layer instead of forcing every workspace item to be a `Clip`. Keep `Clip` as history/source data, with `CanvasObject` owning workspace-specific visual state such as position, size, z-index, style, object kind, and optional clip linkage. Build a shared `WorkspaceActionRegistry` before AI so direct UI actions, App Intents, OpenAI tools, and future MCP tools all mutate the workspace through the same validated interface.

**Tech Stack:** SwiftUI, SwiftData, iOS/iPadOS/macOS/visionOS target support, PencilKit-ready object model, current `Clip`, `Workspace`, `CanvasPlacement`, `AIChat`, `ChatMessage`, and `ChatAttachment` models.

---

## Supersedes

This plan supersedes the broad canvas, AI, and drawing assumptions in `2026-05-12-clipcanvas-rewrite.md` while keeping historical docs intact. It depends on `2026-05-13-clip-version-history-transforms.md` for clip versioning because transforms should mutate reusable clip source data rather than create disconnected duplicates.

## Product Direction

ClipCanvas becomes a visual workspace for thinking with captured information.

- Clipboard history is the main capture stream, not the whole product.
- Canvas objects are sticky-note-like workspace items that may or may not be backed by clipboard clips.
- Canvas tap selects or edits objects. It does not copy to the clipboard by default.
- Clipboard history rows keep copy-to-clipboard as their primary action because they are the clipboard-focused surface.
- The canvas adds value through structure: spatial grouping, connections, diagrams, handwritten conversion, AI transforms, and workspace-level arrangement.

## Core Model

Create a new workspace object layer:

```swift
enum CanvasObjectKind: String, Codable, CaseIterable {
    case stickyNote
    case clipNote
    case image
    case drawing
    case shape
    case connector
    case group
}

enum CanvasShapeKind: String, Codable, CaseIterable {
    case rectangle
    case roundedRectangle
    case circle
    case diamond
    case capsule
}

struct CanvasObjectStyle: Codable, Equatable {
    var fillHex: String
    var strokeHex: String?
    var textHex: String?
    var lineWidth: Double
    var fontSize: Double
}

struct CanvasConnectorEndpoint: Codable, Equatable {
    var objectID: UUID?
    var point: CGPointCodable
    var anchor: CanvasAnchor
}

enum CanvasAnchor: String, Codable, CaseIterable {
    case center
    case top
    case trailing
    case bottom
    case leading
    case free
}
```

SwiftData additions:

```swift
@Model
final class CanvasObject {
    var id: UUID = UUID()
    var kindRaw: String
    var workspace: Workspace?
    var clip: Clip?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double = 0
    var zIndex: Double = 0
    var text: String = ""
    var shapeKindRaw: String?
    var styleData: Data?
    var drawingData: Data?
    var connectorData: Data?
    var groupID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date?
}
```

Existing `CanvasPlacement` is treated as a migration bridge. The implementation should either migrate placements to `CanvasObject(kind: .clipNote)` or keep `CanvasPlacement` temporarily as a compatibility source while new rendering reads through a `CanvasObjectRepresentable` adapter. Prefer a real migration once tests cover parity.

## Shared Action Layer

Create `WorkspaceActionRegistry` and use it from all surfaces:

- Canvas toolbar and topbar.
- Object context menus.
- Selection controls.
- App Intents and Shortcuts.
- AI tool calls.
- Future local MCP bridge on macOS.

Action interface:

```swift
enum WorkspaceActionRisk: String, Codable {
    case safe
    case changesContent
    case destructive
}

struct WorkspaceActionRequest: Codable, Identifiable {
    var id: UUID = UUID()
    var name: WorkspaceActionName
    var workspaceID: UUID
    var argumentsData: Data
    var source: WorkspaceActionSource
}

enum WorkspaceActionSource: String, Codable {
    case user
    case ai
    case appIntent
    case extensionImport
    case mcp
}

struct WorkspaceActionResult: Codable {
    var success: Bool
    var message: String
    var changedObjectIDs: [UUID]
    var changedClipIDs: [UUID]
    var needsConfirmation: Bool
}
```

Initial action names:

- `canvas.createStickyNote`
- `canvas.createClipNote`
- `canvas.updateObjectText`
- `canvas.moveObjects`
- `canvas.resizeObjects`
- `canvas.deleteObjects`
- `canvas.duplicateObjects`
- `canvas.createConnector`
- `canvas.updateConnector`
- `canvas.groupObjects`
- `canvas.ungroupObjects`
- `canvas.arrangeGrid`
- `canvas.fitViewToContent`
- `clip.applyTransform`
- `clip.updateContent`
- `clip.addTags`
- `clip.removeTags`
- `chat.attachObjects`

Workspace actions intentionally excluded:

- Create workspace.
- Delete workspace.
- Rename workspace.
- Activate workspace.

## Implementation Tasks

### Task 1: Object Model Tests

**Files:**
- Create: `ClipCanvasTests/CanvasObjectTests.swift`
- Modify: `ClipCanvas/Models/Workspace.swift`

- [x] Add tests that a sticky note object stores text, size, position, style, and workspace relationship.
- [x] Add tests that a clip-backed object points at a `Clip` without copying clip content.
- [x] Add tests that a connector can target object IDs or free points.
- [x] Add tests that soft-deleting a clip hides clip-backed objects but does not delete the canvas object record until the workspace object is deleted.

### Task 2: Add Canvas Object Models

**Files:**
- Create: `ClipCanvas/Models/CanvasObject.swift`
- Modify: `ClipCanvas/ClipCanvasApp.swift`

- [x] Add `CanvasObject`, `CanvasObjectKind`, `CanvasObjectStyle`, connector endpoint types, and `CGPointCodable`.
- [x] Add `@Relationship(deleteRule: .cascade, inverse: \CanvasObject.workspace)` from `Workspace` to `canvasObjects`.
- [x] Add `CanvasObject.self` to the SwiftData `ModelContainer`.
- [x] Keep `CanvasPlacement` in the schema during the transition so old workspace data still opens.

### Task 3: Placement Compatibility

**Files:**
- Create: `ClipCanvas/Services/CanvasObjectMigrationService.swift`
- Test: `ClipCanvasTests/CanvasObjectMigrationTests.swift`

- [x] Convert each live `CanvasPlacement` into one `CanvasObject(kind: .clipNote)` preserving clip, x, y, width, and height.
- [x] Skip already-migrated placements by storing a deterministic migration marker on `CanvasObject` or by deleting the converted placements after successful migration.
- [x] Run migration once from `AppBootstrap.ensureActiveWorkspace(in:)`.
- [x] Test that migration is idempotent.

### Task 4: Render Canvas Objects

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasView.swift`
- Modify: `ClipCanvas/Views/Canvas/ClipCard.swift`
- Create: `ClipCanvas/Views/Canvas/CanvasObjectView.swift`
- Create: `ClipCanvas/Views/Canvas/ConnectorView.swift`

- [x] Replace the main `ForEach(placements)` path with live `workspace.canvasObjects`.
- [x] Render `.stickyNote` and `.clipNote` with one shared sticky-note view.
- [x] Render `.image`, `.shape`, `.drawing`, `.connector`, and `.group` as separate lightweight subviews.
- [x] Keep grid/background camera math unchanged.
- [x] Keep z-index reshuffle behavior when an object is selected.

### Task 5: Introduce WorkspaceActionRegistry

**Files:**
- Create: `ClipCanvas/Services/WorkspaceActionRegistry.swift`
- Create: `ClipCanvas/Services/WorkspaceActionPermissionService.swift`
- Test: `ClipCanvasTests/WorkspaceActionRegistryTests.swift`

- [x] Implement pure validation for all initial action names.
- [x] Implement mutation handlers for safe object actions first: create sticky note, update object text, move, resize, duplicate, arrange grid, fit view.
- [x] Implement destructive object delete with `needsConfirmation == true` when `source == .ai`.
- [x] Reject workspace create/delete/rename/activate actions for AI, App Intent, and MCP sources.
- [x] Add tests for the permission matrix.

### Task 6: Change Canvas Primary Interaction

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasMode.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasToolbar.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasContainerView.swift`
- Modify: `ClipCanvas/Views/Common/ClipRowView.swift`

- [x] Change canvas tap from copy-to-clipboard to select in normal mode.
- [x] Keep clipboard history row primary action as copy-to-clipboard.
- [x] Add explicit copy action to selected canvas object toolbar/context menu.
- [x] Update copy-on-tap setting text or remove it from canvas behavior.

## Acceptance Criteria

- Existing clipboard history still stores deduplicated clips.
- Existing workspaces open and show migrated clip notes.
- Canvas can show non-clip sticky notes.
- Canvas object actions go through `WorkspaceActionRegistry`.
- Clipboard history keeps copy as primary action; canvas objects do not.
- The app still builds for the iPhone simulator with no warnings.

## Commit Plan

1. `feat: add canvas object model`
2. `feat: migrate placements to canvas objects`
3. `refactor: render canvas objects`
4. `feat: add workspace action registry`
5. `refactor: make canvas tap select objects`

## References

- Existing prerequisite plan: `docs/superpowers/plans/2026-05-13-clip-version-history-transforms.md`
- Current canvas files: `ClipCanvas/Views/Canvas/CanvasView.swift`, `ClipCanvas/Views/Canvas/CanvasContainerView.swift`, `ClipCanvas/Views/Canvas/CanvasToolbar.swift`
