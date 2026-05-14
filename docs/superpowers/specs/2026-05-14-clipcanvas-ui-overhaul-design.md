# ClipCanvas UI Overhaul — Design Spec

**Date:** 2026-05-14
**Approach:** Fix foundation first (Sections 1–4, 7–8), then new canvas features (Sections 5–6).
**Principle:** Less is more. The UI reveals context-appropriate actions rather than always showing everything.

---

## Section 1 — Toolbar & Interaction Philosophy

### Core principle

The toolbar is a context mirror. It always shows exactly what makes sense for the current mode and selection state. Nothing permanent except the three mode buttons (in the default state).

### Toolbar states

**Pan mode, nothing selected:**
```
[ paste ] | [ pan ] [ edit ] [ draw ]
```

**Pan mode, 1+ objects selected:**
```
[ AI ✦ ] | [ arrange ] [ details ] | [ delete ]
```
- AI → `askAIAboutSelection` (attaches selected objects)
- Details disabled when selection count > 1
- Delete is destructive-tinted

**Edit mode, nothing selected:**
```
[ paste ] | [ pan ] [ edit ] [ draw ]
```

**Edit mode, 1+ selected (not actively editing):**
```
[ ✎ edit ] | [ color ] [ tags ] | [ delete ]
```
- Edit button on far left with divider — tapping opens inline editing on the selected note

**Edit mode, 1 note actively being edited:**
```
[ ✎ edit ] | [ bullet ] [ color ] | [ done ]
```
- Edit icon stays as inactive anchor
- Done exits editing, keeps note selected
- Bullet toggles NSTextList on current paragraph
- Bold is deferred to v2 — not shown in toolbar yet
- Color opens color picker popover

**Draw mode:**
```
[ pen ] [ highlighter ] [ eraser ] [ lasso ] | [ convert ] [ save ] [ clear ]
```

### Implementation

`CanvasToolbarConfiguration.make(selectedCount:mode:isEditing:)` gets a new `isEditing: Bool` parameter to distinguish the two edit-mode states. `CanvasToolbarItem` gains `.editContent`, `.bold`, `.bullet`, `.color`, `.done` cases as needed.

---

## Section 2 — Context Menus

### Workspace top bar menu

**Problem:** `CanvasTopBar` currently uses `confirmationDialog` (action sheet from bottom). Restore to `Menu { }` anchored to the ellipsis button — renders as liquid glass dropdown on iOS 26.

**Menu items (unchanged):**
```
Rename
Fit to Cards
Arrange Grid
─────────────
Clear Cards  (destructive)
```

Clear Cards keeps its confirmation `alert` — the destructive action still requires confirmation, but the first trigger is now a `Menu` item, not an action sheet.

### Object context menus

`CanvasObjectView` already uses `.contextMenu { }` — already liquid glass on iOS 26. No change.

### Add/Cancel/Done button styling

All inline Add, Cancel, and Done buttons use `appSelectionButtonStyle()` / `appSelectionIconButtonStyle()` from `BlendedControls.swift` consistently. No custom one-off button styles.

---

## Section 3 — Notes

### Shape

Keep `StickyNoteShape` but refine the fold geometry:
- Fold triangle size reduced to ~12pt (from current)
- Cleaner corner join at the fold
- Slightly larger overall corner radius

### Exit editing — interaction model

| Mode | Tap note | Tap outside | Swipe down | Mode change |
|------|----------|-------------|------------|-------------|
| Pan | Selects | Deselects | — | — |
| Edit (not editing) | Opens inline edit | Deselects | — | Exits, deselects |
| Edit (editing) | — | Exits edit, keeps selected | Exits edit, keeps selected | Exits, deselects |

The `editingObjectID` binding in `CanvasContainerView` drives this:
- Tapping canvas background: `selectedObjectIDs.removeAll()` + `editingObjectID = nil`
- Swipe down on `CanvasObjectView`: `editingObjectID = nil` only (selection preserved)
- Mode change: `editingObjectID = nil` + `selectedObjectIDs.removeAll()`

### Text editor reliability

Replace `InlineNoteEditor` (TextEditor-based) with `UIViewRepresentable` wrapping `UITextView`:
- `isScrollEnabled = false` — eliminates internal scroll drift
- `contentOffset = .zero` reset in `textViewDidEndEditing` — no stale scroll on exit
- Commits on every `textViewDidChange` — exiting never loses the last keystroke
- Autosizes to fill the note's current bounds exactly

### Rich text — bullet points

`UITextView` with `NSTextList` toggled by the bullet toolbar button. Toggle on/off per paragraph. Only bullet lists in v1 — bold/italic buttons exist in toolbar but are deferred.

### Font scaling (Miro-style)

Note font size derived from note width:
```swift
let fontSize = (object.width / 18.0).clamped(to: 11...22)
```
Content is centered vertically and horizontally within the note frame. Font recalculates on every resize event.

### Resize rework

**Math:**
- Remove `snappedTextWidth` / `snappedTextHeight` (character-grid approach)
- Replace with fluid drag clamped to min/max, then soft-snapped to 16pt grid:
  ```swift
  func softSnap(_ value: CGFloat) -> CGFloat {
      (value / 16).rounded() * 16
  }
  ```
- Min size = `defaultSize` (220×150) — cannot drag smaller
- Max size = `expandedSize()` result (content-driven)

**Double-tap resize handle:** Toggles between `defaultSize` and `expandedSize()`. The existing `onToggleExpandedSize` action is preserved — only the underlying math changes.

---

## Section 4 — Workspace Name Backdrop

**Problem:** `WorkspaceTitleBackdrop` applies a horizontal `LinearGradient` mask to `ultraThinMaterial`. The mask clips the blur kernel at the edges, causing visibly unblurred edges.

**Fix:** Remove the gradient mask. Use a clean unmasked capsule:

```swift
private struct WorkspaceTitleBackdrop: View {
    var body: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        }
    }
}
```

The `CanvasTopBarFade` gradient above handles the top-bar visual fade — the capsule does not need to replicate it.

---

## Section 5 — Drawing Mode

### Architecture

A `PKCanvasView` rendered as `UIViewRepresentable` (`CanvasDrawingLayer`) sits above all canvas objects in the `CanvasView` ZStack. It is inserted only when `mode == .draw`.

The drawing layer shares the canvas viewport transform (origin + scale) so ink lands in world coordinates.

### Ink lifecycle

- Active strokes: view-local `@State var activeDrawing: PKDrawing`
- Save: creates `CanvasObject(kind: .drawing, drawingData: activeDrawing.dataRepresentation())`
- Convert: runs `DrawingConversionService`, creates structured `CanvasObject` records, clears ink
- Clear: resets `activeDrawing` to `PKDrawing()`

### Tool palette

The draw mode toolbar drives tool selection via `@State var activeTool: PKInkingTool` passed into the `CanvasDrawingLayer` coordinator. PencilKit's native `PKToolPicker` is not used.

```
[ pen ] [ highlighter ] [ eraser ] [ lasso ] | [ convert ] [ save ] [ clear ]
```

### Convert — v1 scope

- Handwriting → `CanvasObject(kind: .stickyNote, text: recognizedText)` via `VNRecognizeTextRequest`
- Non-text ink → saved as drawing object
- Arrow and shape classification: deferred to v2 (stub exists in `DrawingConversionService`)

### Object hit testing

While `mode == .draw` and actively inking, canvas objects have `allowsHitTesting(false)`. Interacting with existing objects requires switching back to pan or edit mode.

---

## Section 6 — Diagramming Connectors

### Philosophy

Loose, not structured. No rigid port system. Drag from an edge handle, drop on a note or empty canvas.

### Creating a connector

When a note is selected in pan mode, four cardinal edge handles appear (top, bottom, leading, trailing). Dragging from a handle creates a new `CanvasObject(kind: .connector)` live:
- In-progress connector renders as a dashed line with arrow tip
- Drop within 40pt of another object → endpoint snaps to that object's nearest edge anchor
- Drop on empty canvas → free endpoint in canvas coordinates

### Rendering

`ConnectorView` draws a `Path` between two resolved endpoints:
- Anchored endpoint: derived from referenced object's current position + edge anchor offset
- Free endpoint: stored canvas coordinate
- Style: 2pt stroke, `Color.primary.opacity(0.7)`, filled triangle arrow tip at destination
- Moving a connected object live-updates the connector

### Selection and deletion

Tap hit region on the connector line (12pt wide). Selecting shows toolbar: `[ delete ]` only.

### Model

`CanvasObject.connectorData: Data?` decodes to:
```swift
struct CanvasConnectorData: Codable {
    var start: CanvasConnectorEndpoint
    var end: CanvasConnectorEndpoint
}
struct CanvasConnectorEndpoint: Codable {
    var objectID: UUID?
    var anchor: CanvasAnchor
    var point: CGPointCodable   // fallback / free endpoint
}
```
These types already exist in the codebase.

### Not in v1 scope

Connector labels, curved paths, multiple arrow styles, color picker for connectors.

---

## Section 7 — AI Chat Input

### Problem

The model mode `Picker` lives in `chatHeader` as a segmented control — always visible, takes vertical space.

### New input bar

```
[ message field ................................. ] [ ⌄ mode ] [ ▶ send ]
```

- Mode button: 60pt wide, 44pt tall, capsule with `.regularMaterial` fill, shows current mode abbreviation + chevron
- Tapping presents a `Menu`:
  ```
  ✓ Quick
    Thinking
    (future slots)
  ```
- Send button: existing circle arrow button, unchanged

### Revised chat header

Strip down to a single passive info line:
```
Workspace: My Board    claude-sonnet-4-6
```
Small, secondary, non-interactive. Model label updates to reflect mode selection.

### Future extensibility

The mode `Menu` is the extension point — attach context, temperature, provider — all slot in without changing the input bar layout.

---

## Section 8 — Sidebar List Items

### List row style

Workspace and chat rows use a lighter card — same `AppListItemBackground` shape but at 5–8% opacity instead of 12–20%. Retains visual grouping without the heavy card feel. Clips section remains unchanged.

### Add workspace button

The Workspaces section header gets a `+` button alongside "View all" — same pattern as the AI Chats section header:

```swift
Button(action: createWorkspace) {
    Image(systemName: "plus")
}
.buttonStyle(BlendedIconButtonStyle(size: 34))
```

`createWorkspace()`:
1. Inserts new `Workspace` with placeholder name `"New Workspace"`
2. Sets `renamingWorkspace = newWorkspace` immediately
3. Keyboard appears, user types and submits — commits the real name

### Swipe actions — workspace rows

- Trailing: Delete (destructive)
- Leading: Rename (orange) — triggers inline rename, same as context menu

### Swipe actions — chat rows

- Trailing: Delete (destructive)

### Context menus preserved

Both workspace and chat rows keep `.contextMenu { }` for long-press. Swipe actions are additive.

---

---

## Section 9 — Undo/Redo & Zoom Controls

### Undo/redo system

Canvas mutations go through `WorkspaceActionRegistry` already. Add an `UndoManager` instance owned by `CanvasContainerView`, passed into action executors. Each registry action registers its inverse on commit.

A new `CanvasUndoControls` view — styled identically to `CanvasZoomControls` — sits to the left of the zoom controls in the bottom-right cluster:

```
[ ↩ ] [ ↪ ]   [ + ]
               [ % ]
               [ - ]
```

Both controls are vertical capsule pills with the same glass background. The undo pill is horizontal (two buttons side by side) to keep the footprint compact.

Undo/redo buttons are disabled (0.4 opacity) when the stack is empty.

**Scope:** Undoable actions in v1 — move, resize, text edit, delete, paste/add. Drawing strokes use PencilKit's built-in undo support via `PKCanvasView.undoManager`.

### Zoom controls — scale text squish

Current layout stacks `+`, scale `Text`, and `−` in a `VStack`, giving the scale label its own 18pt height slot. New layout: the scale text is a zero-height overlay centred between the two buttons, not a VStack item:

```swift
ZStack {
    VStack(spacing: 0) {
        zoomButton("plus", action: onZoomIn)
        zoomButton("minus", action: onZoomOut)
    }
    Text("\(Int((scale * 100).rounded()))%")
        .font(.system(size: 9, weight: .semibold).monospacedDigit())
        .foregroundStyle(.secondary)
        .allowsHitTesting(false)
}
```

The total pill height shrinks from `40 + 5 + 18 + 5 + 40 + 10` to `40 + 40 + 10` pt. The scale label sits centred in the gap between the two buttons, rendered on top with `allowsHitTesting(false)`.

---

## Files Affected

| File | Change |
|------|--------|
| `CanvasMode.swift` | Add `isEditing` to `CanvasToolbarConfiguration.make`, new toolbar items |
| `CanvasToolbar.swift` | New toolbar states, AI/edit/bold/bullet/color/done items |
| `CanvasTopBar.swift` | Replace `confirmationDialog` with `Menu`, fix `WorkspaceTitleBackdrop` |
| `CanvasContainerView.swift` | Wire `isEditing` state, tap-outside deselect + exit-edit logic |
| `CanvasObjectView.swift` | Swipe-down gesture to exit editing, font scaling, shape refinement |
| `CanvasPlacementSizing.swift` | Replace character-grid snap with fluid + 16pt soft-snap |
| `StickyNoteShape.swift` | Refined fold geometry (create if not exists) |
| `InlineNoteEditor.swift` | Replace TextEditor with UITextView UIViewRepresentable |
| `CanvasDrawingLayer.swift` | New — PKCanvasView representable |
| `DrawingConversionService.swift` | New — Vision text recognition stub |
| `ConnectorView.swift` | Endpoint-anchored Path rendering, hit region |
| `CanvasView.swift` | Insert drawing layer in draw mode, connector edge handles on selection |
| `AIChatDetailSheet.swift` | Move mode picker to input bar as Menu button |
| `SidebarView.swift` | Add workspace + button, lighter card opacity, create workspace action |
| `WorkspaceRowView.swift` | Lower card opacity, add swipe actions |
| `CanvasZoomControls.swift` | Scale text overlay (zero-height), squished pill |
| `CanvasUndoControls.swift` | New — undo/redo pill, mirrors zoom pill style |
| `CanvasContainerView.swift` | Own `UndoManager`, pass to action registry |

## Commit Sequence

1. `fix: toolbar context states and add/cancel/done button styling`
2. `fix: workspace context menu — restore liquid glass Menu dropdown`
3. `fix: workspace name backdrop blur — remove gradient mask`
4. `fix: note editing exit — UITextView, swipe-down, tap-outside`
5. `feat: note resize — fluid soft-snap, font scaling, min/max toggle`
6. `feat: drawing mode — PencilKit layer and tool palette`
7. `feat: diagramming connectors — edge handles, path rendering, snap`
8. `feat: ai chat — model mode dropdown in input bar`
9. `feat: sidebar — add workspace button, swipe actions, lighter rows`
10. `feat: canvas undo/redo system and zoom control squish`
