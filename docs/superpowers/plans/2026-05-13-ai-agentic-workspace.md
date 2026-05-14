# AI Agentic Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a continuous, context-aware AI chat and transform system where OpenAI chat, Apple Intelligence transforms, workspace actions, and future MCP tools coexist through one shared action and skill layer.

**Architecture:** Keep the current `AIChat`, `ChatMessage`, and `ChatAttachment` models instead of resurrecting the obsolete `AISession` plan. Add a shared `TransformSkillRegistry` for local Apple Intelligence transforms and OpenAI-invoked skills, and route all canvas/clip mutations through `WorkspaceActionRegistry`. Use OpenAI Responses, Conversations, streaming, function tools, and MCP-compatible schemas for continuous chat state and tool execution.

**Tech Stack:** SwiftUI, SwiftData, Foundation Models, OpenAI Responses API, OpenAI Conversations API, streaming server-sent events, function tools, MCP-compatible JSON schemas, existing `AIChat` models.

---

## Current API Check

As of May 14, 2026, keep the OpenAI implementation on the Responses API:

- Responses supports stored response state, streaming, tool choice, function tools, and MCP tools through the `tools` parameter.
- Streaming emits typed semantic events such as response lifecycle, output text deltas, function-call arguments, MCP-call arguments, completion, and errors.
- Conversations support continuing state across turns and include MCP approval request/response item types.

Do not reintroduce Assistants-style thread abstractions. `AIChat`, `ChatMessage`, `ChatAttachment`, and `AIToolEvent` remain the app source of truth.

## Current Implementation Status

- Done: `AIChatMode`, `ChatMessageStatus`, `AIToolEvent`, `AIContextPacker`, `AIModelPresetService`, `TransformSkillRegistry`, `WorkspaceActionRegistry`, `AIWorkspaceToolExecutor`, and the first `AIChatDetailSheet`.
- Done: AI tool execution is routed through `WorkspaceActionRegistry` and rejects workspace create/delete/rename/activate actions.
- Done: context packing excludes private clip bodies by default.
- Done: deterministic text-transform fallbacks are centralized in `TextTransformFallbacks`, and the edit selection toolbar can manually apply selected-note transforms through `TransformSkillRegistry`.
- Done: `WorkspaceActionRegistry` handles clip content updates, local clip transforms, clip tag add/remove, and chat object attachment, so OpenAI tools and user-triggered transforms share the same mutation path.
- Remaining: real `OpenAIResponsesClient`, streamed response loop, function/MCP argument streaming, inline confirmation continuation, retry handling, and replacing placeholder assistant responses.

## Supersedes

This plan supersedes the AI portions of `2026-05-12-clipcanvas-rewrite.md`. The old plan introduced `AISession` and `AIMessage`; this branch already has `AIChat`, `ChatMessage`, and `ChatAttachment`, so implementation must extend those current models.

## Prerequisites

- `2026-05-13-clip-version-history-transforms.md` for in-place clip versions.
- `2026-05-13-visual-workspace-roadmap.md` through at least `WorkspaceActionRegistry`.

## AI Modes

```swift
enum AIChatMode: String, Codable, CaseIterable {
    case quick
    case thinking
}

struct AIModelPreset: Codable, Equatable {
    var mode: AIChatMode
    var model: String
    var reasoningEffort: String
    var maxContextObjects: Int
}
```

Defaults:

- Quick: `gpt-5.4-mini`, `reasoning.effort = none`, compact context, low latency.
- Thinking: `gpt-5.5`, `reasoning.effort = high`, broader context, visible workspace summary, selected objects, attachments, and recent tool history.

Keep these defaults in `AIModelPresetService` so future settings can expose them without hardcoding model IDs across views.

## Model Changes

Extend `AIChat`:

```swift
var modeRaw: String = AIChatMode.quick.rawValue
var openAIConversationID: String?
var lastResponseID: String?
var isPinned: Bool = false
```

Extend `ChatMessage`:

```swift
enum ChatMessageStatus: String, Codable {
    case pending
    case streaming
    case completed
    case failed
    case cancelled
}

var statusRaw: String = ChatMessageStatus.completed.rawValue
var errorMessage: String?
var openAIResponseID: String?
```

Add:

```swift
@Model
final class AIToolEvent {
    var id: UUID = UUID()
    var message: ChatMessage?
    var toolName: String
    var statusRaw: String
    var summary: String
    var argumentsData: Data?
    var resultData: Data?
    var createdAt: Date = Date()
    var completedAt: Date?
}
```

Tool statuses: `queued`, `running`, `needsConfirmation`, `completed`, `failed`.

## Context Packing

Create `AIContextPacker`.

Context sources in priority order:

1. Explicit chat attachments.
2. Selected canvas objects.
3. Visible canvas objects.
4. Active workspace summary.
5. Recent relevant clipboard history.
6. Recent tool events in this chat.

Private content policy:

- Mask private/password clips by default.
- Exclude private clip bodies from model context unless the user explicitly reveals and attaches them for that turn.
- Include safe metadata such as "private clip omitted" so the model can explain missing context.

## Transform Skill Layer

Create:

```swift
protocol TransformSkill {
    var id: String { get }
    var title: String { get }
    var risk: WorkspaceActionRisk { get }
    func run(input: TransformSkillInput) async throws -> TransformSkillResult
}
```

Initial skills:

- `clip.cleanUp`
- `clip.distill`
- `clip.actionItems`
- `clip.rewrite`
- `clip.title`
- `clip.suggestTags`
- `canvas.createStickyNotesFromText`
- `canvas.arrangeIntoGrid`
- `canvas.summarizeVisibleObjects`
- `canvas.createDiagramFromNotes`

Provider policy:

- Use Foundation Models for local text transforms when available.
- Fall back to deterministic local transforms for tests.
- Use OpenAI for chat, generation, multi-object reasoning, diagram creation, and tool orchestration.

## OpenAI Tool Schema

Expose these tool names to OpenAI:

- `canvas_create_sticky_note`
- `canvas_update_object_text`
- `canvas_move_objects`
- `canvas_resize_objects`
- `canvas_delete_objects`
- `canvas_duplicate_objects`
- `canvas_create_connector`
- `canvas_arrange_grid`
- `canvas_fit_view_to_content`
- `clip_apply_transform`
- `clip_add_tags`
- `clip_remove_tags`
- `chat_attach_objects`

Each tool handler converts OpenAI JSON arguments into a `WorkspaceActionRequest`. The handler must not mutate models directly.

Permission rules:

- AI may create, edit, move, resize, duplicate, tag, attach, transform, arrange, and delete canvas objects after confirmation when destructive.
- AI may create clips or sticky notes as part of a user-requested transform/generation.
- AI may not create, delete, rename, or activate workspaces.
- AI may not reveal private clip content.
- AI may request that the user reveal/attach private content.

## UI Requirements

Create an `AIChatDetailView` for the existing `AIChatsPage`.

- Header: title, mode segmented control, selected attachments count, new chat action.
- Message list: user bubbles, assistant bubbles, streaming assistant text, tool event rows, error rows.
- Input bar: text field, attach selected, attach visible, send button.
- Throbber: use animated dots while no text has streamed yet; switch to streaming text once deltas arrive.
- Tool event rows: "Thinking", "Reading selected notes", "Creating sticky note", "Waiting for confirmation", "Applied transform".
- Confirmation UI: destructive tool event presents Confirm/Cancel inline.
- Graceful errors: failed message remains visible with Retry and Copy Error.

## Implementation Tasks

### Task 1: Extend AI Models

**Files:**
- Modify: `ClipCanvas/Models/AIChat.swift`
- Modify: `ClipCanvas/ClipCanvasApp.swift`
- Test: `ClipCanvasTests/AIChatModelTests.swift`

- [x] Add `AIChatMode`, `ChatMessageStatus`, and `AIToolEvent`.
- [x] Add SwiftData schema registration for `AIToolEvent`.
- [x] Test sorted messages, mode default, attachment states, and tool event status changes.

### Task 2: Add AI Context Packer

**Files:**
- Create: `ClipCanvas/Services/AIContextPacker.swift`
- Test: `ClipCanvasTests/AIContextPackerTests.swift`

- [x] Build context snapshots from attachments, selected object IDs, visible object IDs, workspace summary, and recent history.
- [x] Enforce quick vs thinking object limits.
- [x] Exclude private clip content by default.
- [x] Test truncation, ordering, and private clipping behavior.

### Task 3: Add TransformSkillRegistry

**Files:**
- Create: `ClipCanvas/Services/TransformSkillRegistry.swift`
- Create: `ClipCanvas/Services/FoundationTransformProvider.swift`
- Test: `ClipCanvasTests/TransformSkillRegistryTests.swift`

- [x] Register the initial skill list.
- [x] Route text transforms through Foundation Models when available.
- [x] Provide deterministic fallback implementations for tests and unavailable local models.
- [x] Return `TransformSkillResult` with changed clip IDs or proposed canvas actions.

### Task 4: Add OpenAI Client

**Files:**
- Create: `ClipCanvas/Services/OpenAIResponsesClient.swift`
- Test: `ClipCanvasTests/OpenAIResponsesClientTests.swift`

- [ ] Create response requests using conversation IDs when available.
- [ ] Stream semantic events into `AIStreamEvent` values.
- [ ] Parse output text deltas, function-call arguments, completion, and errors.
- [ ] Include `AIModelPresetService` for quick/thinking defaults.
- [ ] Mock URL loading in tests; no live network calls.

### Task 5: Add AI Tool Executor

**Files:**
- Create: `ClipCanvas/Services/AIWorkspaceToolExecutor.swift`
- Test: `ClipCanvasTests/AIWorkspaceToolExecutorTests.swift`

- [x] Map OpenAI tool names to `WorkspaceActionRequest`.
- [x] Create `AIToolEvent` rows before execution.
- [x] Return `needsConfirmation` for destructive AI requests.
- [x] Reject workspace-management actions.
- [x] Execute non-destructive clip update, transform, tag, and chat attachment tools through `WorkspaceActionRegistry`.
- [ ] Write tool results back to the OpenAI response loop only after the action registry returns success.

### Task 6: Build Chat UI

**Files:**
- Create: `ClipCanvas/Views/AI/AIChatDetailView.swift`
- Create: `ClipCanvas/Views/AI/ChatMessageBubble.swift`
- Create: `ClipCanvas/Views/AI/AIToolEventRow.swift`
- Modify: `ClipCanvas/Views/AIChats/AIChatsPage.swift`

- [x] Make chat rows open `AIChatDetailSheet`.
- [x] Add quick/thinking mode control.
- [ ] Add streaming assistant bubble and throbber.
- [x] Add inline tool event rows.
- [ ] Add inline confirmation buttons.
- [ ] Add attach selected/visible object actions from canvas entry points.

### Task 7: Connect Canvas Entry Points

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasToolbar.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasContainerView.swift`
- Modify: `ClipCanvas/Views/Canvas/ClipDetailSheet.swift`

- [x] Add "Ask AI" action for selected or visible canvas objects.
- [ ] Add transform skill actions to details and selected-object toolbar.
- [x] Attach selected or visible objects to a new or existing chat.
- [ ] Keep undo/redo and editing sent messages out of scope.

## Acceptance Criteria

- Existing AI list becomes a usable chat surface.
- Quick and Thinking modes use centralized model presets.
- Streaming shows a throbber and incremental assistant text.
- Tool calls create visible activity rows.
- Destructive AI actions require inline confirmation.
- AI cannot manipulate workspaces.
- AI can create notes, edit clips, tag clips, attach clips, arrange canvas objects, and run transforms through shared registries.

## Commit Plan

1. `feat: extend ai chat models`
2. `feat: add ai context packer`
3. `feat: add transform skill registry`
4. `feat: add openai responses client`
5. `feat: add ai tool executor`
6. `feat: build ai chat detail view`
7. `feat: connect ai workspace actions`

## References

- OpenAI Responses API: https://platform.openai.com/docs/api-reference/responses/retrieve
- OpenAI conversation state: https://platform.openai.com/docs/guides/conversation-state?api-mode=responses
- OpenAI streaming: https://platform.openai.com/docs/guides/streaming-responses
- OpenAI tools and MCP: https://platform.openai.com/docs/guides/tools?api-mode=responses
- OpenAI models: https://developers.openai.com/api/docs/models
- Apple Foundation Models `LanguageModelSession`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
