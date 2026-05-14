# Miro-Style Workspace, MCP, and Collaboration Roadmap

> **Status:** Superseding plan. Keep old plans as history; use this document for the next workspace/AI/collaboration implementation slices.

## Summary

ClipCanvas should become a visual thinking workspace, not a clipboard manager with a canvas bolted on. Clipboard history remains an input stream. The core product becomes a board of notes, images, drawings, connectors, groups, and AI actions over those objects.

This plan also keeps the codebase small: user actions, AI tools, App Intents, and future MCP all go through one shared action layer. No second action system for AI. No duplicated toolbar/menu behavior. No screen-specific tag editor forks.

Current OpenAI direction remains Responses API plus tools/MCP. OpenAI documents Responses as the advanced interface for model responses with function tools and MCP tools, and their tools guide describes remote MCP servers as a way to extend model capabilities through the `tools` parameter.

Sources:
- https://platform.openai.com/docs/api-reference/responses
- https://platform.openai.com/docs/guides/tools
- https://platform.openai.com/docs/guides/tools-remote-mcp
- https://platform.openai.com/docs/docs-mcp

## Product Direction

The app should feel closer to Miro, Freeform, and Apple Notes:

- A workspace is a board.
- A note is the primary editable object.
- Clipboard items become source records that can create notes.
- Canvas cards should be renamed toward notes in UI and new internal APIs.
- Drawings should become useful objects: handwriting notes, connectors, shapes, boundaries, and diagrams.
- AI is a collaborator that can inspect selected or visible board objects and propose or perform allowed board actions.

## Naming Migration

Use conservative migration:

- Keep `Clip` as the persisted clipboard/source model for now.
- Introduce UI terminology as "Note" and "Card" where the user is manipulating canvas objects.
- Add new code around `CanvasObject` and `Note` concepts; do not rename every existing file in one risky pass.
- Future persistence migration can add `NoteSource` or `SourceClip` once canvas object behavior is stable.

Rules:

- New canvas editing APIs should say object/note, not clip.
- Clipboard history APIs can still say clip until a storage migration exists.
- Details screens should say "Note Details".
- Workspace actions should say cards/notes when affecting the canvas, and clipboard only when affecting history.

## Shared Action Architecture

All externally visible mutations go through `WorkspaceActionRegistry`:

- Toolbar actions.
- Context menu actions.
- App Intents.
- Share/Action extension imports.
- OpenAI function tools.
- Remote/local MCP tools.
- Future collaboration command replay.

Do not add direct SwiftData mutation paths for AI-only behavior.

Action registry additions:

- `canvas.create_note`
- `canvas.update_note_text`
- `canvas.set_note_tags`
- `canvas.create_shape`
- `canvas.create_connector`
- `canvas.update_connector`
- `canvas.group_objects`
- `canvas.ungroup_objects`
- `canvas.align_grid`
- `canvas.fit_view`
- `canvas.attach_to_chat`
- `clipboard.import_source`

AI, App Intents, and MCP still cannot create, delete, rename, or activate workspaces unless explicitly added later with a separate account/permission model.

## MCP Plan

Build a local app MCP adapter around the same action registry.

V1 tools:

- `list_workspaces`: read-only, returns IDs and active workspace.
- `get_workspace_snapshot`: read-only, returns selected/visible/all object summaries.
- `get_object_details`: read-only, returns note text, tags, source metadata, and privacy redactions.
- `create_note`: writes through `WorkspaceActionRegistry`.
- `update_note_text`: writes through `WorkspaceActionRegistry`.
- `move_objects`: writes through `WorkspaceActionRegistry`.
- `resize_objects`: writes through `WorkspaceActionRegistry`.
- `arrange_grid`: writes through `WorkspaceActionRegistry`.
- `create_connector`: writes through `WorkspaceActionRegistry`.
- `set_tags`: writes through tag actions.
- `attach_objects_to_chat`: writes chat attachments.

Implementation constraints:

- Tool schemas are generated from action argument structs where possible.
- Destructive actions require confirmation and should return a confirmation request, not mutate.
- Private clips/notes are redacted unless explicitly revealed/attached.
- Tool results return changed object IDs and a short user-facing summary.
- The app can expose the MCP adapter locally first; remote MCP is a later account/security feature.

## OpenAI Chat Integration

Use Responses API with:

- Quick mode: `gpt-5.4-mini`.
- Thinking mode: `gpt-5.5`.
- `AIContextPacker` for selected, visible, attached, private, and large-board cases.
- Function tools for direct in-app actions.
- MCP-compatible schemas so the same tool definitions can be used locally or remotely.
- Streaming response and tool-event rows in `AIChatDetailSheet`.

Do not use Assistants-style thread abstractions. Existing `AIChat`, `ChatMessage`, `ChatAttachment`, and `AIToolEvent` remain the source of truth.

## Collaboration And Accounts

Collaboration should be planned around command replay and object-level sync:

- Each workspace mutation becomes a compact action event.
- Sync applies events through the same action registry validation.
- Conflicts resolve at object-field level where possible.
- Canvas objects need stable IDs, updated timestamps, and eventually revision counters.

Account providers to plan for:

- Apple/iCloud for first-party Apple ecosystem sync.
- Google for cross-platform identity and Drive-style sharing later.
- Microsoft for work/school accounts and OneDrive/SharePoint-adjacent futures.

V1 collaboration should not be real-time multiplayer. Start with:

- Single-user iCloud sync.
- Action log persistence.
- Conflict-safe object updates.
- Shareable read-only exports.

Real-time collaboration comes after the action log is proven.

## Implementation Tasks

### Task 1: Finish Note Terminology Layer

- [ ] Rename user-facing canvas labels from clip/card mix to note/card consistently.
- [ ] Add a `CanvasNoteSurface` shared view for note rendering.
- [ ] Keep `Clip` as source storage and document the source/note boundary.
- [ ] Add tests for note detail titles and action labels where practical.

### Task 2: Extract Canvas Interaction Services

- [x] Move zoom stepping into a tested service.
- [x] Move resize snapping into a tested service.
- [x] Move arrange-grid layout math out of `CanvasView`.
- [x] Move bounds math out of `CanvasView`.
- [ ] Keep `CanvasView` focused on rendering and gesture orchestration.

### Task 3: Build AI Tool Executor

- [x] Map tool names to `WorkspaceActionRequest`.
- [x] Create `AIToolEvent` before execution.
- [x] Return confirmation requests for destructive actions.
- [x] Reject workspace management actions.
- [x] Add tests for success, rejection, confirmation, and error rows.

### Task 4: Implement Streaming Chat Detail

- [ ] Replace placeholder assistant replies with streaming message updates.
- [ ] Show a throbber while waiting.
- [x] Render tool events inline.
- [ ] Add Quick/Thinking mode persistence.
- [x] Add attach selected/visible object actions.

### Task 5: Add Local MCP Adapter

- [ ] Define MCP tool schema generation from action arguments.
- [ ] Implement read-only workspace snapshot tools.
- [ ] Implement write tools through `WorkspaceActionRegistry`.
- [ ] Add privacy redaction and confirmation behavior.
- [ ] Add unit tests for schema shape and tool execution.

### Task 6: Prepare Collaboration Event Log

- [ ] Add `WorkspaceActionEvent` persistence.
- [ ] Record successful local user actions.
- [ ] Make actions replayable in tests.
- [ ] Add object-level conflict tests.
- [ ] Defer network sync until local replay is stable.

## Test Plan

- Unit test action registry permissions for user, AI, App Intent, MCP, and future collaboration sources.
- Unit test tool schema generation.
- Unit test AI context packing with selected, visible, attached, private, and large-board cases.
- Unit test resize snapping and zoom stepping.
- Unit test arrange-grid layout independent of SwiftUI.
- Unit test action replay from a blank workspace into expected canvas state.
- UI smoke test AI chat creation and medium-detent sheet presentation.

## Guardrails

- Prefer small files with focused responsibilities.
- No new global singleton action services.
- No duplicated tag editors.
- No AI-only mutation bypasses.
- No full model renames without a migration plan.
- Every broad UI behavior should have either a shared component or a documented reason it is unique.
