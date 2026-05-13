# Draw, Edit, and Diagramming Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Normal, Edit, and Draw modes useful for a visual workspace, with drawing converted into structured sticky notes, shapes, connectors, and diagrams rather than remaining decorative ink.

**Architecture:** Mode controls change primary interaction semantics without creating separate canvas implementations. Normal mode selects and organizes objects, Edit mode prioritizes inline content manipulation, and Draw mode places a PencilKit layer above canvas objects and can convert ink into structured `CanvasObject` records through Vision, geometry heuristics, and AI-assisted interpretation.

**Tech Stack:** SwiftUI, PencilKit, Vision, Foundation Models/OpenAI through `TransformSkillRegistry`, shared `CanvasObject` model, shared `WorkspaceActionRegistry`.

---

## Product Rationale

Drawing is useful only if it creates structure. The canvas should feel closer to a Miro-style thinking board than a clipboard visualizer.

Draw mode exists for:

- Quickly sketching relationships before formalizing them.
- Turning handwriting into sticky notes.
- Turning arrows into real connectors.
- Turning boxes/circles into shape nodes.
- Turning rough boundaries into groups.
- Giving AI visual context for diagram creation and reorganization.

## Modes

```swift
enum CanvasMode: Equatable {
    case normal
    case edit
    case draw
}
```

Normal mode:

- Tap object: select.
- Double tap text/sticky note: edit.
- Drag background: pan canvas.
- Drag object: move.
- Toolbar emphasizes paste/import, create sticky note, ask AI, arrange, copy, delete, details.

Edit mode:

- Tap text/sticky note: immediately edit content.
- Tap image/drawing/shape: show edit handles/properties.
- Toolbar emphasizes text style, color, tags, transform, details.
- Copy and delete are available through context menu or overflow, not primary toolbar slots.

Draw mode:

- Pencil/stylus or finger creates ink above objects.
- Existing objects remain visible and selectable only through an explicit selection toggle.
- Toolbar shows pen, highlighter, eraser, lasso, convert, clear ink, save as drawing.
- Convert action creates structured objects and removes or archives the raw ink depending on user choice.

## Structured Drawing Outputs

V1 conversion outputs:

- Handwriting block -> `CanvasObject(kind: .stickyNote, text: recognizedText)`.
- Arrow stroke -> `CanvasObject(kind: .connector, connectorData: endpoints)`.
- Rectangle/circle/diamond sketch -> `CanvasObject(kind: .shape)`.
- Boundary stroke around multiple objects -> group action.
- Mixed sketch -> AI-assisted "diagram from ink" skill producing multiple workspace actions.

Raw drawings can still be saved:

- Save ink as `CanvasObject(kind: .drawing, drawingData: PKDrawing.dataRepresentation())`.
- Convert to image clip only when user explicitly chooses "Save as image clip".

## Diagramming Interactions

Connectors:

- Drag from object edge handles to another object.
- Snap endpoints to nearest edge anchor.
- Free endpoints remain in canvas coordinates.
- Moving an object updates connected endpoint rendering.
- Deleting an object soft-breaks connectors and shows a missing endpoint state.

Groups:

- Lasso or boundary conversion creates a group object with child object IDs.
- Group selection moves children together.
- Ungroup keeps child positions unchanged.

Arrange:

- Arrange selected into grid using top-left anchoring and object sizes.
- Arrange connected objects should preserve connector references.
- Fit view after arrange remains a view command, not content mutation.

## Implementation Tasks

### Task 1: Rename and Stabilize Canvas Modes

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasMode.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasToolbar.swift`
- Test: `ClipCanvasTests/CanvasModeTests.swift`

- [x] Replace `.pan` with `.normal`.
- [x] Keep `.draw` and add `.edit`.
- [x] Add mode-specific toolbar configuration tests for available actions.
- [x] Preserve existing pan gesture in normal mode.

### Task 2: Add Edit Mode Behavior

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasView.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasObjectView.swift`
- Create: `ClipCanvas/Views/Canvas/InlineStickyNoteEditor.swift`

- [ ] In edit mode, tapping text or sticky-note objects opens inline editing.
- [ ] In normal mode, tapping selects only.
- [ ] Persist edits through `WorkspaceActionRegistry.canvas_update_object_text`.
- [ ] Submit with keyboard Done and cancel focus when mode changes.

### Task 3: Add PencilKit Draw Layer

**Files:**
- Create: `ClipCanvas/Views/Canvas/CanvasDrawingLayer.swift`
- Create: `ClipCanvas/Models/CanvasInkArchive.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasView.swift`

- [ ] Render `PKCanvasView` above canvas objects only in draw mode.
- [ ] Keep drawing in world coordinates by applying the same viewport origin and scale as objects.
- [ ] Store active drawing strokes in a view-local `PKDrawing` until user saves or converts.
- [ ] Disable object hit-testing while actively drawing.

### Task 4: Add Drawing Tool Palette

**Files:**
- Create: `ClipCanvas/Views/Canvas/DrawingToolPalette.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasToolbar.swift`

- [ ] Add pen, highlighter, eraser, lasso, convert, save drawing, and clear ink actions.
- [ ] Use touch-sized circular controls consistent with existing toolbar style.
- [ ] Keep drawing controls in unsafe-area-aware bottom toolbar.
- [ ] Hide unrelated copy/delete/tag actions while drawing unless object selection toggle is active.

### Task 5: Add Drawing Conversion Service

**Files:**
- Create: `ClipCanvas/Services/DrawingConversionService.swift`
- Create: `ClipCanvas/Services/DrawRecognitionService.swift`
- Test: `ClipCanvasTests/DrawingConversionServiceTests.swift`

- [ ] Use Vision text recognition for handwriting blocks.
- [ ] Use stroke geometry to classify arrows, boxes, circles, diamonds, and boundaries.
- [ ] Return `[WorkspaceActionRequest]` instead of mutating SwiftData directly.
- [ ] Add deterministic tests using serialized sample stroke fixtures.

### Task 6: Add Connector Editing

**Files:**
- Create: `ClipCanvas/Views/Canvas/ConnectorEndpointHandle.swift`
- Modify: `ClipCanvas/Views/Canvas/ConnectorView.swift`
- Test: `ClipCanvasTests/CanvasConnectorTests.swift`

- [ ] Add endpoint handles when connector is selected.
- [ ] Snap endpoint to nearest object edge within a fixed threshold.
- [ ] Support free endpoint placement when no object is nearby.
- [ ] Update connector through `WorkspaceActionRegistry.canvas_updateConnector`.

### Task 7: Add Group and Arrange UX

**Files:**
- Modify: `ClipCanvas/Services/WorkspaceActionRegistry.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasToolbar.swift`
- Test: `ClipCanvasTests/CanvasGroupingTests.swift`

- [ ] Add group and ungroup actions for selected objects.
- [ ] Move grouped children together.
- [ ] Preserve child z-order inside group.
- [ ] Arrange selected objects into a size-aware grid anchored from the top-left of each object.

## Selection Toolbar Matrix

Normal mode selected actions:

- Copy.
- Ask AI.
- Arrange.
- Group/Ungroup.
- Details.
- Delete.

Edit mode selected actions:

- Edit text.
- Color/style.
- Tags.
- Transform.
- Details.

Draw mode actions:

- Pen/highlighter/eraser/lasso.
- Convert.
- Save drawing.
- Clear ink.

## Acceptance Criteria

- Drawing ink renders above objects and follows the same zoom/pan transform.
- Edit mode tap starts inline editing for text/sticky notes.
- Normal mode tap selects without copying to clipboard.
- Converted handwriting creates sticky notes.
- Converted arrows create connectors.
- Group and connector behavior survives moving/arranging objects.
- Drawing conversion returns workspace actions and does not bypass the action registry.

## Commit Plan

1. `refactor: add canvas edit mode`
2. `feat: add pencil drawing layer`
3. `feat: add drawing tool palette`
4. `feat: convert drawings into canvas objects`
5. `feat: add connector editing`
6. `feat: add grouping and arrange tools`

## References

- PencilKit: https://developer.apple.com/documentation/pencilkit
- Vision text recognition: https://developer.apple.com/documentation/vision
- Apple Foundation Models `LanguageModelSession`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
