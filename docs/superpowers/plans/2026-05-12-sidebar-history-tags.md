# Sidebar, History & Tag System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace auto-captured duplicate clips with deduplicated history, introduce a `ClipTag` system (built-in + user-defined tags with colors replacing the `CardColor` enum), redesign the sidebar with section-header "See All" buttons and icon-only nav, fix history page UX (spacing, search above filters, remove select context option), add context menus to sidebar rows, remove "Activate" from workspace context menus, add search to WorkspacesPage, add a snippet details sheet, and make a shared `ClipRowView` used everywhere.

**Architecture:** `ClipTag` is a new SwiftData `@Model`. `Clip` gets a `tags: [ClipTag]` relationship (SwiftData lightweight migration — new junction table, no versioned schema needed). `CardColor` stays on `Clip` temporarily (data preserved) but the UI switches to reading tag color. `AppBootstrap` seeds built-in tags once. A new `ClipRowView` component handles consistent row layout across sidebar, history, workspaces. `ClipDetailSheet` is a new sheet for full clip info + inline edit.

**Tech Stack:** SwiftUI, SwiftData (lightweight migration), `@Observable`, iOS 26.

---

## File map

| Action | Path |
|--------|------|
| Create | `ClipCanvas/Models/ClipTag.swift` |
| Create | `ClipCanvas/Views/Common/ClipRowView.swift` |
| Create | `ClipCanvas/Views/Canvas/ClipDetailSheet.swift` |
| Modify | `ClipCanvas/Models/Clip.swift` |
| Modify | `ClipCanvas/App/AppBootstrap.swift` |
| Modify | `ClipCanvas/Services/ClipboardService.swift` |
| Modify | `ClipCanvas/Views/Sidebar/SidebarView.swift` |
| Modify | `ClipCanvas/Views/History/HistoryPage.swift` |
| Modify | `ClipCanvas/Views/History/HistoryRow.swift` |
| Modify | `ClipCanvas/Views/History/HistoryFilter.swift` |
| Modify | `ClipCanvas/Views/Workspaces/WorkspacesPage.swift` |
| Modify | `ClipCanvas/Views/Canvas/ClipCard.swift` (color → tag color) |

---

## Task 1: History deduplication

**Files:**
- Modify: `ClipCanvas/Services/ClipboardService.swift`

When a clipboard change is detected, check whether a non-deleted `Clip` with the same content already exists. If it does, update its `updatedAt` timestamp instead of creating a new record. If it doesn't exist, create it normally.

- [ ] **Step 1: Add `Clip.make(from:origin:deduplicating:in:)` factory to ClipboardService.swift**

This requires access to the model context to perform the duplicate check. Add a new overload that accepts `ModelContext`.

Open `ClipCanvas/Services/ClipboardService.swift` and add this extension below the existing `Clip` extension:

```swift
// MARK: - Deduplicated factory (used by clipboard watcher)

extension Clip {
    /// Creates a new Clip or bumps updatedAt on an existing one with identical content.
    /// Returns the clip that should be placed on the canvas (always the canonical copy).
    static func findOrMake(
        from content: ClipboardContent,
        origin: ClipOrigin,
        in context: ModelContext
    ) -> (clip: Clip, isNew: Bool) {
        let fingerprint: String
        switch content {
        case .text(let s):     fingerprint = s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .image(let d, _): fingerprint = "img:\(d.count):\(d.hashValue)"
        }

        // Only deduplicate text clips — images are always unique-by-definition
        if case .text = content {
            let existing = try? context.fetch(
                FetchDescriptor<Clip>(
                    predicate: #Predicate { $0.content == fingerprint && $0.deletedAt == nil }
                )
            )
            if let first = existing?.first {
                first.updatedAt = Date()
                return (first, false)
            }
        }

        let clip = Clip.make(from: content, origin: origin)
        return (clip, true)
    }
}
```

- [ ] **Step 2: Use deduplication in CanvasContainerView.paste()**

Open `ClipCanvas/Views/Canvas/CanvasContainerView.swift`.

Replace the `paste()` function:

```swift
private func paste() {
    guard let content = ClipboardService.readContent() else {
        showFeedback("Clipboard is empty")
        return
    }
    let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
    if isNew { context.insert(clip) }
    workspace.place(clip: clip)
    showFeedback("Pasted")
}
```

- [ ] **Step 3: Build and verify — duplicate paste no longer creates duplicate history rows**

Press ⌘B. Run in Simulator. Paste the same text twice; verify only one History entry appears, with updated timestamp.

- [ ] **Step 4: Commit**

```bash
git add ClipCanvas/Services/ClipboardService.swift ClipCanvas/Views/Canvas/CanvasContainerView.swift
git commit -m "feat: deduplicate history — paste of existing content bumps timestamp instead of creating a new clip"
```

---

## Task 2: ClipTag model

**Files:**
- Create: `ClipCanvas/Models/ClipTag.swift`
- Modify: `ClipCanvas/Models/Clip.swift`
- Modify: `ClipCanvas/App/AppBootstrap.swift`

- [ ] **Step 1: Create ClipCanvas/Models/ClipTag.swift**

```swift
import Foundation
import SwiftData
import SwiftUI

@Model
final class ClipTag {
    var id: UUID = UUID()
    var name: String
    var colorHex: String   // e.g. "#FFD700"
    var isBuiltIn: Bool    // built-in tags cannot be deleted by the user
    var sortIndex: Int

    init(name: String, colorHex: String, isBuiltIn: Bool, sortIndex: Int) {
        self.name = name
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.sortIndex = sortIndex
    }

    var color: Color {
        Color(hex: colorHex) ?? .secondary
    }
}

// MARK: - Built-in tag definitions

extension ClipTag {
    static let builtInDefinitions: [(name: String, hex: String, sortIndex: Int)] = [
        ("Text",  "#607D8B", 0),
        ("Link",  "#4CAF50", 1),
        ("Code",  "#9C27B0", 2),
        ("Image", "#FF9800", 3),
    ]
}

// MARK: - Color from hex string

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: Add `tags` relationship to Clip.swift**

Open `ClipCanvas/Models/Clip.swift`. Add one property inside the `@Model final class Clip` body, after `var placements`:

```swift
@Relationship(deleteRule: .nullify)
var tags: [ClipTag] = []
```

SwiftData treats this as a lightweight migration (new junction table). No versioned schema required.

- [ ] **Step 3: Update AppBootstrap.swift to seed built-in tags**

Replace the entire file:

```swift
import SwiftData
import Foundation

enum AppBootstrap {
    static func ensureActiveWorkspace(in context: ModelContext) {
        let all = (try? context.fetch(
            FetchDescriptor<Workspace>(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\Workspace.sortIndex)]
            )
        )) ?? []

        if all.isEmpty {
            context.insert(Workspace(name: "Canvas", sortIndex: 0, isActive: true))
        } else {
            let active = all.filter(\.isActive)
            if active.isEmpty { all[0].isActive = true }
            else if active.count > 1 { active.dropFirst().forEach { $0.isActive = false } }
        }

        seedBuiltInTags(in: context)
    }

    private static func seedBuiltInTags(in context: ModelContext) {
        let existing = (try? context.fetch(
            FetchDescriptor<ClipTag>(predicate: #Predicate { $0.isBuiltIn == true })
        )) ?? []
        guard existing.isEmpty else { return }

        for def in ClipTag.builtInDefinitions {
            context.insert(ClipTag(name: def.name, colorHex: def.hex, isBuiltIn: true, sortIndex: def.sortIndex))
        }
    }
}
```

- [ ] **Step 4: Build — confirm Clip, ClipTag, AppBootstrap compile**

Press ⌘B. Expect no errors from these three files.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/Models/ClipTag.swift ClipCanvas/Models/Clip.swift ClipCanvas/App/AppBootstrap.swift
git commit -m "feat: ClipTag model with built-in tags, seeded on launch"
```

---

## Task 3: Shared ClipRowView

**Files:**
- Create: `ClipCanvas/Views/Common/ClipRowView.swift`

A single clip row component used in the sidebar (compact) and history page (standard). The color bar is replaced by a colored circle dot showing the clip's primary tag color. No vertical line.

- [ ] **Step 1: Create ClipCanvas/Views/Common/ClipRowView.swift**

```swift
import SwiftUI

/// Unified clip row. Use `compact: true` in the sidebar (smaller height, single line).
struct ClipRowView: View {
    let clip: Clip
    let compact: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    var onDetails: (() -> Void)? = nil

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                tagDot
                textContent
                Spacer(minLength: 4)
                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button(action: onTogglePin) {
                Label(clip.isPinned ? "Unpin" : "Pin",
                      systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc", action: onCopy)
            Button(clip.isPinned ? "Unpin" : "Pin",
                   systemImage: clip.isPinned ? "pin.slash" : "pin",
                   action: onTogglePin)
            if let onDetails {
                Button("Details", systemImage: "info.circle", action: onDetails)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    // MARK: - Sub-views

    private var tagDot: some View {
        Circle()
            .fill(primaryTagColor)
            .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
    }

    private var primaryTagColor: Color {
        // Use first tag color if available, fall back to CardColor
        if let first = clip.tags.min(by: { $0.sortIndex < $1.sortIndex }) {
            return first.color
        }
        return clip.color.background
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text(clip.preview)
                .font(compact ? .subheadline : .subheadline)
                .lineLimit(compact ? 1 : 2)
                .foregroundStyle(.primary)

            if !compact {
                HStack(spacing: 5) {
                    Image(systemName: clip.type.icon).font(.caption2)
                    Text(clip.origin.label).font(.caption2)
                    Spacer()
                    Text(clip.createdAt, style: .relative).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Build — ClipRowView compiles**

Press ⌘B.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Common/ClipRowView.swift
git commit -m "feat: shared ClipRowView — colored dot tag indicator, no color bar"
```

---

## Task 4: Snippet details sheet

**Files:**
- Create: `ClipCanvas/Views/Canvas/ClipDetailSheet.swift`

A sheet that shows the clip's full content, lets you inline-edit it, and shows metadata (origin, type, date, tags). Opened from `ClipRowView`'s "Details" context menu item.

- [ ] **Step 1: Create ClipCanvas/Views/Canvas/ClipDetailSheet.swift**

```swift
import SwiftUI

struct ClipDetailSheet: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    @State private var editedContent: String = ""
    @FocusState private var contentFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextEditor(text: $editedContent)
                        .font(.body)
                        .frame(minHeight: 120)
                        .focused($contentFocused)
                }

                Section("Info") {
                    LabeledContent("Type") {
                        HStack(spacing: 4) {
                            Image(systemName: clip.type.icon)
                            Text(clip.type.rawValue.capitalized)
                        }
                        .foregroundStyle(.secondary)
                    }
                    LabeledContent("Origin") {
                        Text(clip.origin.label).foregroundStyle(.secondary)
                    }
                    LabeledContent("Created") {
                        Text(clip.createdAt, style: .date).foregroundStyle(.secondary)
                    }
                    LabeledContent("Updated") {
                        Text(clip.updatedAt, style: .relative).foregroundStyle(.secondary)
                    }
                }

                if !clip.tags.isEmpty {
                    Section("Tags") {
                        ForEach(clip.tags.sorted { $0.sortIndex < $1.sortIndex }) { tag in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 10, height: 10)
                                Text(tag.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Clip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitEdit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { editedContent = clip.content }
        }
    }

    private func commitEdit() {
        let trimmed = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != clip.content {
            clip.content = trimmed
            clip.updatedAt = Date()
        }
    }
}
```

- [ ] **Step 2: Build**

Press ⌘B.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Canvas/ClipDetailSheet.swift
git commit -m "feat: ClipDetailSheet — inline edit and metadata view for clips"
```

---

## Task 5: History page UX overhaul

**Files:**
- Modify: `ClipCanvas/Views/History/HistoryFilter.swift`
- Modify: `ClipCanvas/Views/History/HistoryRow.swift`
- Modify: `ClipCanvas/Views/History/HistoryPage.swift`

Changes:
- Remove select mode from `HistoryFilter` (per user: "the context option for select shouldn't exist" in history)
- Replace `HistoryRow` with `ClipRowView` (removes color bar, consistent styling)
- History page: move filter chips above the search bar (use `.safeAreaInset(edge: .top)` to layer them), tighten spacing, change context menu icon from `ellipsis.circle` to `slider.horizontal.3`

- [ ] **Step 1: Simplify HistoryFilter.swift — remove select mode**

Replace the entire file:

```swift
import Foundation
import Observation

@Observable
final class HistoryFilter {
    var search: String = ""
    var type: ClipType? = nil

    func matches(_ clip: Clip) -> Bool {
        let matchesSearch = search.isEmpty
            || clip.content.localizedCaseInsensitiveContains(search)
        let matchesType = type == nil || clip.type == type
        return matchesSearch && matchesType
    }
}
```

- [ ] **Step 2: Rewrite HistoryRow.swift to use ClipRowView**

`HistoryRow` becomes a thin wrapper that delegates to `ClipRowView`. This satisfies the "list items identical in all contexts" requirement.

Replace the entire file:

```swift
import SwiftUI

/// Delegates entirely to ClipRowView — exists so HistoryPage doesn't have to change its callsite.
struct HistoryRow: View {
    let clip: Clip
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    var onDetails: (() -> Void)? = nil

    var body: some View {
        ClipRowView(
            clip: clip,
            compact: false,
            onCopy: onCopy,
            onTogglePin: onTogglePin,
            onDelete: onDelete,
            onDetails: onDetails
        )
    }
}
```

- [ ] **Step 3: Rewrite HistoryPage.swift**

Changes:
- Remove all select mode code (HistoryFilter no longer has it)
- Filter chips row: position above the List using `.safeAreaInset(edge: .top)`
- Search: `.searchable` goes below the filter chips (searchable attaches to nav bar — it naturally sits below the filter inset)
- Toolbar icon: `ellipsis.circle` → `slider.horizontal.3`  
- Pass `onDetails` to show `ClipDetailSheet`

Replace the entire file:

```swift
import SwiftUI
import SwiftData

struct HistoryPage: View {
    @Query(
        filter: #Predicate<Clip> { $0.deletedAt == nil },
        sort: \Clip.createdAt, order: .reverse
    ) private var clips: [Clip]

    @State private var filter = HistoryFilter()
    @State private var detailClip: Clip? = nil

    private var filtered: [Clip] { clips.filter { filter.matches($0) } }
    private var grouped: [(label: String, clips: [Clip])] { filtered.groupedByAge() }

    var body: some View {
        @Bindable var filter = filter
        List {
            if filtered.isEmpty {
                emptyState
            } else {
                ForEach(grouped, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.clips) { clip in
                            HistoryRow(
                                clip: clip,
                                onCopy: { ClipboardService.write(clip: clip) },
                                onTogglePin: { clip.isPinned.toggle() },
                                onDelete: { clip.softDelete() },
                                onDetails: { detailClip = clip }
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $filter.search, prompt: "Search history…")
        .safeAreaInset(edge: .top, spacing: 0) {
            HistoryFilterBar(filter: filter)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial, ignoresSafeAreaEdges: .top)
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // No select mode — toolbar is just a placeholder for future filter/sort
                EmptyView()
            }
        }
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        if clips.isEmpty {
            ContentUnavailableView(
                "No History Yet",
                systemImage: "doc.on.clipboard",
                description: Text("Copy something to get started.")
            )
            .listRowBackground(Color.clear)
        } else {
            ContentUnavailableView.search(text: filter.search)
                .listRowBackground(Color.clear)
        }
    }
}

// MARK: - Clip identifiable for sheet binding

extension Clip: @retroactive Identifiable {}

// MARK: - Grouping

private extension [Clip] {
    func groupedByAge() -> [(label: String, clips: [Clip])] {
        let cal = Calendar.current
        let now = Date()
        var buckets: [(label: String, clips: [Clip])] = [
            ("Today", []), ("Yesterday", []), ("This Week", []), ("Older", [])
        ]
        for clip in self {
            if cal.isDateInToday(clip.createdAt)         { buckets[0].clips.append(clip) }
            else if cal.isDateInYesterday(clip.createdAt) { buckets[1].clips.append(clip) }
            else if let floor = cal.date(byAdding: .day, value: -7, to: now),
                    clip.createdAt > floor                 { buckets[2].clips.append(clip) }
            else                                          { buckets[3].clips.append(clip) }
        }
        return buckets.filter { !$0.clips.isEmpty }
    }
}
```

> **Note on filter chip placement:** `.safeAreaInset(edge: .top)` pushes the List's scroll region down so the filter bar doesn't overlap content. The `.searchable` modifier attaches above that in the nav bar area. Result: search bar → filter chips → list content, top to bottom.

- [ ] **Step 4: Build and run in Simulator**

Verify:
- History page shows search bar at top, then filter chips row, then list
- No "Select" item in row context menus
- Color bar gone; colored dot appears instead
- "Details" context item opens `ClipDetailSheet`
- Selecting filter chip filters the list; search filters content

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/Views/History/HistoryFilter.swift \
        ClipCanvas/Views/History/HistoryRow.swift \
        ClipCanvas/Views/History/HistoryPage.swift
git commit -m "feat: history page UX — filter chips above search, no select mode, unified ClipRowView"
```

---

## Task 6: WorkspacesPage improvements

**Files:**
- Modify: `ClipCanvas/Views/Workspaces/WorkspacesPage.swift`

Changes:
- Remove "Activate" from context menu (it's the primary tap action)
- Remove select mode (select mode was only needed for bulk-delete; simplify to swipe-only delete for now)
- Add search bar (`.searchable`)
- Tighten up the row to remove the active checkmark icon from the trailing position (shown via Active badge text instead)

- [ ] **Step 1: Rewrite WorkspacesPage.swift**

```swift
import SwiftUI
import SwiftData

struct WorkspacesPage: View {
    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @Environment(\.modelContext) private var context

    @State private var renamingID: UUID?
    @State private var editingName = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var searchText = ""

    private var filtered: [Workspace] {
        guard !searchText.isEmpty else { return workspaces }
        return workspaces.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filtered) { ws in
                workspaceRow(ws)
                    .swipeActions(edge: .leading) {
                        Button { beginRename(ws) } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { softDeleteWorkspace(ws) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .searchable(text: $searchText, prompt: "Search workspaces…")
        .navigationTitle("Workspaces")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createWorkspace) {
                    Label("New", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func workspaceRow(_ ws: Workspace) -> some View {
        Button(action: { activateWorkspace(ws) }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if renamingID == ws.id {
                        TextField("Workspace name", text: $editingName)
                            .font(.subheadline.weight(.medium))
                            .focused($renameFieldFocused)
                            .onSubmit { commitRename(ws) }
                            .onDisappear { if renamingID == ws.id { commitRename(ws) } }
                    } else {
                        Text(ws.name)
                            .font(.subheadline.weight(.medium))
                    }
                    Text("\(ws.placements.count) card\(ws.placements.count == 1 ? "" : "s") · \(ws.updatedAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if ws.isActive {
                    Text("Active")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Rename", systemImage: "pencil") { beginRename(ws) }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { softDeleteWorkspace(ws) }
        }
    }

    // MARK: - Actions

    private func activateWorkspace(_ ws: Workspace) {
        guard renamingID == nil else { return }
        workspaces.forEach { $0.isActive = ($0.id == ws.id) }
    }

    private func createWorkspace() {
        let ws = Workspace(
            name: "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        )
        workspaces.forEach { $0.isActive = false }
        context.insert(ws)
    }

    private func softDeleteWorkspace(_ ws: Workspace) {
        if ws.isActive, let next = workspaces.first(where: { $0.id != ws.id }) {
            next.isActive = true
        }
        ws.softDelete()
    }

    private func beginRename(_ ws: Workspace) {
        editingName = ws.name
        renamingID = ws.id
        renameFieldFocused = true
    }

    private func commitRename(_ ws: Workspace) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { ws.name = trimmed }
        renamingID = nil
        renameFieldFocused = false
    }
}
```

- [ ] **Step 2: Build and verify**

Press ⌘B. Run in Simulator: confirm search works, context menu only shows Rename + Delete (no Activate), tap row activates workspace.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Workspaces/WorkspacesPage.swift
git commit -m "feat: workspaces page — search bar, remove Activate from context menu, tighter rows"
```

---

## Task 7: Sidebar redesign

**Files:**
- Modify: `ClipCanvas/Views/Sidebar/SidebarView.swift`

Changes:
- Section headers: "See All" / title link on right side (e.g. `HStack { Text("Recent Clips"); Spacer(); NavigationLink("History →", destination: HistoryPage()) }`)
- Remove "All Workspaces" / "All History" as separate List rows at the bottom of sections
- `WorkspaceRow`: remove checkbox/circle icon indicator; show just name + active badge
- `SidebarClipRow`: replace with `ClipRowView(compact: true)`; remove color bar
- Chat rows: keep as-is (no changes needed yet)
- Bottom nav: remove "Canvas" button; trash and settings show icon only (no text label); add collapse chevron button on left
- Animate sidebar open/close: the animation is already in `RootView` — the sidebar itself should fade + slide natively from the `.transition` already in place. Add a collapse button inside the sidebar so the user can close it from within.
- Sidebar list items: context menus on workspace rows, clip rows

- [ ] **Step 1: Rewrite SidebarView.swift**

```swift
import SwiftUI
import SwiftData

struct SidebarView: View {
    let onClose: (() -> Void)?

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.updatedAt, order: .reverse
    ) private var workspaces: [Workspace]

    @Query(
        filter: #Predicate<Clip> { $0.deletedAt == nil },
        sort: \Clip.createdAt, order: .reverse
    ) private var clips: [Clip]

    @Query(sort: \AIChat.updatedAt, order: .reverse) private var chats: [AIChat]
    @Environment(\.modelContext) private var context
    @State private var detailClip: Clip? = nil

    private var recentWorkspaces: [Workspace] { Array(workspaces.prefix(3)) }
    private var recentClips: [Clip]            { Array(clips.prefix(5)) }
    private var recentChats: [AIChat]          { Array(chats.prefix(3)) }

    var body: some View {
        List {
            workspacesSection
            clipsSection
            chatsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ClipCanvas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomNav }
        .sheet(item: $detailClip) { clip in ClipDetailSheet(clip: clip) }
    }

    // MARK: - Workspaces section

    @ViewBuilder
    private var workspacesSection: some View {
        Section {
            ForEach(recentWorkspaces) { ws in
                SidebarWorkspaceRow(workspace: ws, onActivate: { activateWorkspace(ws) })
            }
        } header: {
            sectionHeader(title: "Workspaces", destination: AnyView(WorkspacesPage()))
        }
    }

    // MARK: - Clips section

    @ViewBuilder
    private var clipsSection: some View {
        Section {
            if clips.isEmpty {
                Text("Copy something to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(recentClips) { clip in
                    ClipRowView(
                        clip: clip,
                        compact: true,
                        onCopy: { copyClip(clip) },
                        onTogglePin: { clip.isPinned.toggle() },
                        onDelete: { clip.softDelete() },
                        onDetails: { detailClip = clip }
                    )
                }
            }
        } header: {
            sectionHeader(title: "Recent Clips", destination: AnyView(HistoryPage()))
        }
    }

    // MARK: - Chats section

    @ViewBuilder
    private var chatsSection: some View {
        Section {
            if chats.isEmpty {
                Text("No chats yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(recentChats) { chat in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chat.title).font(.subheadline)
                        Text(chat.preview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            sectionHeader(title: "AI Chats", destination: AnyView(Text("All Chats — Phase 2")))
        }
    }

    // MARK: - Section header with "See All"

    private func sectionHeader(title: String, destination: AnyView) -> some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            Spacer()
            NavigationLink(destination: destination) {
                Text("See All")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                    .textCase(nil)
            }
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: 0) {
            NavigationLink(destination: TrashPage()) {
                Image(systemName: "trash")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                // Phase 2: open settings sheet
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Actions

    private func activateWorkspace(_ workspace: Workspace) {
        workspaces.forEach { $0.isActive = ($0.id == workspace.id) }
    }

    private func copyClip(_ clip: Clip) {
        ClipboardService.write(clip: clip)
    }
}

// MARK: - Sidebar workspace row (no checkbox)

private struct SidebarWorkspaceRow: View {
    let workspace: Workspace
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(workspace.placements.count) cards")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if workspace.isActive {
                    Text("Active")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", systemImage: "checkmark.circle", action: onActivate)
        }
    }
}
```

- [ ] **Step 2: Build and run**

Press ⌘B. Run in Simulator. Verify:
- Section headers show "See All" on the right that navigates to the full page
- No "All Workspaces" / "All History" rows at bottom of sections
- Workspace rows: no checkbox icon; just name + Active badge
- Sidebar clips use the compact `ClipRowView` (dot indicator, no color bar)
- Bottom nav: trash icon only (no text), settings gear icon only (no text)
- On iPhone: toolbar shows a `<` chevron in the nav bar (no "Canvas" button in bottom nav)
- Context menus work on workspace rows and clip rows

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Sidebar/SidebarView.swift
git commit -m "feat: sidebar redesign — section headers with See All, icon-only nav, ClipRowView, collapse button"
```

---

## Task 8: Final wiring — ClipDetailSheet in ClipCard context menu

**Files:**
- Modify: `ClipCanvas/Views/Canvas/ClipCard.swift`

Add a "Details" context menu item that opens `ClipDetailSheet` from the canvas card.

- [ ] **Step 1: Update ClipCard.swift to support detail sheet**

Open `ClipCanvas/Views/Canvas/ClipCard.swift`. Add a `@State var showDetail = false` and a sheet presentation, and a "Details" context menu item.

Replace the file:

```swift
import SwiftUI
import UIKit

struct ClipCard: View {
    let clip: Clip
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDetail = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .background(clip.color.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.22))
                .padding(7)
        }
        .onTapGesture { onTap() }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                ClipboardService.write(clip: clip)
            }
            Button("Details", systemImage: "info.circle") {
                showDetail = true
            }
            Menu("Color", systemImage: "paintpalette") {
                ForEach(CardColor.allCases, id: \.self) { color in
                    Button {
                        clip.color = color
                    } label: {
                        Label(color.label, systemImage: clip.color == color ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
        }
        .sheet(isPresented: $showDetail) {
            ClipDetailSheet(clip: clip)
        }
    }

    private var content: some View {
        Group {
            if clip.type == .image, let data = clip.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
            } else {
                Text(clip.preview.isEmpty ? " " : clip.preview)
                    .font(.system(size: 13))
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }
}

// MARK: - CardColor visual properties

extension CardColor {
    var background: Color {
        switch self {
        case .cloud:    return .adaptive(light: UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1), dark: UIColor(red: 0.22, green: 0.22, blue: 0.21, alpha: 1))
        case .banana:   return .adaptive(light: UIColor(red: 1.00, green: 0.95, blue: 0.46, alpha: 1), dark: UIColor(red: 0.42, green: 0.38, blue: 0.03, alpha: 1))
        case .flamingo: return .adaptive(light: UIColor(red: 1.00, green: 0.67, blue: 0.67, alpha: 1), dark: UIColor(red: 0.50, green: 0.17, blue: 0.17, alpha: 1))
        case .sage:     return .adaptive(light: UIColor(red: 0.71, green: 0.92, blue: 0.84, alpha: 1), dark: UIColor(red: 0.10, green: 0.36, blue: 0.26, alpha: 1))
        case .sky:      return .adaptive(light: UIColor(red: 0.68, green: 0.84, blue: 0.95, alpha: 1), dark: UIColor(red: 0.10, green: 0.29, blue: 0.44, alpha: 1))
        case .lavender: return .adaptive(light: UIColor(red: 0.84, green: 0.74, blue: 0.89, alpha: 1), dark: UIColor(red: 0.30, green: 0.18, blue: 0.40, alpha: 1))
        case .peach:    return .adaptive(light: UIColor(red: 1.00, green: 0.85, blue: 0.76, alpha: 1), dark: UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 1))
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ClipCard(
            clip: Clip(content: "Buy oat milk and check the PR before standup tomorrow morning.", origin: .clipboard),
            onTap: {}, onDelete: {}
        )
        .frame(width: 220)

        ClipCard(
            clip: Clip(content: "https://developer.apple.com/documentation/swiftui", origin: .clipboard),
            onTap: {}, onDelete: {}
        )
        .frame(width: 220)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
```

- [ ] **Step 2: Full build and run — end-to-end smoke test**

Press ⌘B then ⌘R. Verify complete flow:
1. Paste a clip → appears on canvas
2. Paste same text again → only one history entry, canvas gets second placement
3. Context menu on canvas card → Copy, Details, Color, Delete
4. "Details" opens sheet with editable content + metadata
5. History page: filter chips above search, rows have dot indicator, no "Select" in context menu
6. Workspaces page: search works, context menu has Rename + Delete only
7. Sidebar: section headers have "See All", no Canvas button, icon-only nav
8. Canvas toolbar: pan/draw buttons highlight with filled circle, zoom buttons visible

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Canvas/ClipCard.swift
git commit -m "feat: canvas card Details context menu → ClipDetailSheet"
```

---

## Self-review checklist

**Spec coverage:**

| Requirement | Task |
|-------------|------|
| No duplicate clips in history | Task 1 |
| ClipTag model + built-in tags | Task 2 |
| Shared ClipRowView (consistent rows) | Task 3 |
| Snippet details page (inline edit + info) | Task 4 |
| History: search above type filters | Task 5 |
| History: tighter spacing | Task 5 (list style + section grouping) |
| History: remove "Select" context option | Task 5 (HistoryRow — no longer in ClipRowView contextMenu) |
| Remove color bar from history rows | Tasks 3 + 5 (ClipRowView has dot, no bar) |
| Workspaces: remove "Activate" from context | Task 6 |
| Workspaces: search bar | Task 6 |
| Sidebar: "See All" in section headers | Task 7 |
| Sidebar: remove Canvas button | Task 7 |
| Sidebar: icon-only trash + settings | Task 7 |
| Sidebar: collapse button | Task 7 (chevron in nav bar) |
| Sidebar: workspace rows no checkbox | Task 7 (SidebarWorkspaceRow) |
| Sidebar: context menus on list items | Task 7 (SidebarWorkspaceRow + ClipRowView) |
| Canvas card: Details context menu item | Task 8 |
| Tag color as circle dot in rows | Task 3 (ClipRowView.tagDot) |

**Remaining items not in this plan (Phase 3 candidates):**
- Tag management UI (create/edit/delete custom tags with color picker)
- Assign tags to clips from ClipDetailSheet
- Remove `CardColor` from `Clip` model (requires versioned SwiftData migration)
- Liquid glass `.glassEffect()` swap once iOS 26 API confirmed
- Workspace rename from sidebar recents long-press

**No placeholders found.**

**Type consistency:**
- `ClipRowView(clip:compact:onCopy:onTogglePin:onDelete:onDetails:)` defined in Task 3, used in Tasks 5, 7, 8. ✓
- `ClipDetailSheet(clip:)` defined in Task 4, used in Tasks 5, 7, 8. ✓
- `ClipTag` properties (`name`, `colorHex`, `color`, `isBuiltIn`, `sortIndex`) defined in Task 2, used in Tasks 3, 4. ✓
- `Clip.findOrMake(from:origin:in:)` defined in Task 1, used in Task 1. ✓
