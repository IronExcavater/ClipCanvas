# Canvas & Toolbar Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the checkbox select mode from the canvas, convert clip cards to clean sticky notes, add drag animations, overhaul the toolbar into a large liquid-glass drawing-toolbar-style control with zoom and circular mode selection, and add workspace rename + context menu to the top bar.

**Architecture:** All changes are view-layer only. `CanvasMode.select` is removed; `.pan` and `.draw` remain. `CanvasContainerView` loses `watchClipboard` (auto-capture) and all select-state. A new `ZoomCommand` enum lets the toolbar trigger animated zoom in `CanvasView`. State for canvas scale/offset stays in `CanvasView`; the command is a binding from the container. `ClipCard` loses its footer and selection chrome; drag animations are applied in `positionedCard`.

**Tech Stack:** SwiftUI, iOS 26, `DragGesture`, `MagnificationGesture`. Liquid glass: iOS 26 introduces a new `.glassEffect()` modifier — use it where available and fall back to `.regularMaterial`.

---

## File map

| Action | Path |
|--------|------|
| Modify | `ClipCanvas/Views/Canvas/CanvasMode.swift` |
| Modify | `ClipCanvas/Views/Canvas/CanvasContainerView.swift` |
| Modify | `ClipCanvas/Views/Canvas/CanvasView.swift` |
| Modify | `ClipCanvas/Views/Canvas/ClipCard.swift` |
| Modify | `ClipCanvas/Views/Canvas/CanvasToolbar.swift` |
| Modify | `ClipCanvas/Views/Canvas/CanvasTopBar.swift` |

---

## Task 1: Remove select mode and auto-clipboard

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasMode.swift`
- Modify: `ClipCanvas/Views/Canvas/CanvasContainerView.swift`

- [ ] **Step 1: Rewrite CanvasMode.swift — remove `.select`, add `ZoomCommand`**

Replace the entire file:

```swift
enum CanvasMode: Equatable {
    case pan    // default: drag pans canvas, tap card copies to clipboard
    case draw   // PencilKit layer (Phase 2 — mode exists but no drawing yet)
}

enum ZoomCommand: Equatable {
    case zoomIn
    case zoomOut
    case recenter
}
```

- [ ] **Step 2: Rewrite CanvasContainerView.swift**

Remove `selectedIDs`, `watchClipboard`, `enterSelectMode`, `deleteSelected`, `copySelected`, `onSelectModeEntry`. Add `zoomCommand`, `isRenaming`, `renameText`, `renameFocused`. Pass new interface to `CanvasView` and `CanvasToolbar`.

Replace the entire file:

```swift
import SwiftUI
import SwiftData

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void

    @Environment(\.modelContext) private var context
    @State private var mode: CanvasMode = .pan
    @State private var feedback: String?
    @State private var zoomCommand: ZoomCommand? = nil
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        ZStack {
            CanvasView(
                workspace: workspace,
                mode: mode,
                zoomCommand: $zoomCommand,
                onCopyClip: copyToClipboard
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CanvasTopBar(
                    workspaceName: workspace.name,
                    isRenaming: $isRenaming,
                    renameText: $renameText,
                    renameFocused: $renameFocused,
                    onToggleSidebar: onToggleSidebar,
                    onBeginRename: beginRename,
                    onCommitRename: commitRename,
                    onClearAll: clearAll
                )

                Spacer()

                CanvasToolbar(
                    mode: $mode,
                    onPaste: paste,
                    onZoomIn:  { zoomCommand = .zoomIn },
                    onZoomOut: { zoomCommand = .zoomOut },
                    onRecenter: { zoomCommand = .recenter }
                )
            }

            if let feedback {
                VStack {
                    Spacer().frame(height: 70)
                    FeedbackBanner(message: feedback)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: feedback != nil)
    }

    // MARK: - Clipboard

    private func paste() {
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        let clip = Clip.make(from: content, origin: .clipboard)
        context.insert(clip)
        workspace.place(clip: clip)
        showFeedback("Pasted")
    }

    private func copyToClipboard(_ clip: Clip) {
        ClipboardService.write(clip: clip)
        showFeedback("Copied")
    }

    // MARK: - Rename

    private func beginRename() {
        renameText = workspace.name
        isRenaming = true
        renameFocused = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { workspace.name = trimmed }
        isRenaming = false
        renameFocused = false
    }

    // MARK: - Workspace actions

    private func clearAll() {
        let toDelete = workspace.placements
        toDelete.forEach { context.delete($0) }
        workspace.updatedAt = Date()
        showFeedback(toDelete.isEmpty ? "Canvas is already empty" : "Canvas cleared")
    }

    // MARK: - Feedback

    private func showFeedback(_ msg: String) {
        withAnimation { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
    }
}
```

- [ ] **Step 3: Build — confirm no compile errors from removed `mode == .select` references**

In Xcode, press ⌘B. Errors will appear in `CanvasView.swift`, `CanvasTopBar.swift`, `CanvasToolbar.swift` because they still reference `mode == .select` or old callback signatures. That's expected — subsequent tasks fix each one.

- [ ] **Step 4: Commit**

```bash
git add ClipCanvas/Views/Canvas/CanvasMode.swift ClipCanvas/Views/Canvas/CanvasContainerView.swift
git commit -m "feat: remove select mode and auto-clipboard from canvas"
```

---

## Task 2: Update CanvasView — remove select mode, add zoom command, drag animations

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasView.swift`

- [ ] **Step 1: Rewrite CanvasView.swift**

Key changes:
- Remove `selectedIDs` binding and `onSelectModeEntry`
- Change `onCopyClip` callback (was used from select mode path too) — now cards always copy
- Add `@Binding var zoomCommand: ZoomCommand?`
- In `positionedCard`: apply scale 1.05 + drop shadow when `isDragging`
- In `ZStack`: remove `mode == .select` guard on pan gesture (gesture: `mode == .pan ? canvasPanGesture : nil`)
- Add `handleZoom` called via `onChange(of: zoomCommand)`
- Remove `onTapGesture` on the dot grid that did `selectedIDs.removeAll()`
- `ClipCard` now receives `(clip:, onTap:, onDelete:)` — no `isSelected`, `isSelectMode`, `onLongPress`

Replace the entire file:

```swift
import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    let mode: CanvasMode
    @Binding var zoomCommand: ZoomCommand?
    let onCopyClip: (Clip) -> Void

    @Environment(\.modelContext) private var context
    @State private var canvasOffset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var activeDrag: (id: UUID, offset: CGSize)? = nil

    private var placements: [CanvasPlacement] {
        workspace.placements.filter { $0.clip?.deletedAt == nil }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dotGrid(in: geo)
                    .contentShape(Rectangle())
                    .gesture(mode == .pan ? canvasPanGesture : nil)

                ForEach(placements) { placement in
                    if let clip = placement.clip {
                        positionedCard(placement: placement, clip: clip)
                    }
                }

                if placements.isEmpty { EmptyCanvasHint() }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .simultaneousGesture(pinchGesture(in: geo))
            .onChange(of: zoomCommand) { _, cmd in
                guard let cmd else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    handleZoom(cmd, in: geo)
                }
                zoomCommand = nil
            }
        }
        .onChange(of: mode) { _, _ in
            // nothing to do — modes are pan/draw only now
        }
    }

    // MARK: - Dot grid

    private func dotGrid(in geo: GeometryProxy) -> some View {
        Canvas { ctx, size in
            let spacing = max(28.0 * canvasScale, 12)
            let radius   = min(1.2 * canvasScale, 2)
            var x = canvasOffset.width.truncatingRemainder(dividingBy: spacing)
            if x < 0 { x += spacing }
            while x < size.width + spacing {
                var y = canvasOffset.height.truncatingRemainder(dividingBy: spacing)
                if y < 0 { y += spacing }
                while y < size.height + spacing {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                               width: radius * 2, height: radius * 2)),
                        with: .color(.secondary.opacity(0.22))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Card positioning

    private func positionedCard(placement: CanvasPlacement, clip: Clip) -> some View {
        let scale     = canvasScale
        let offset    = canvasOffset
        let centerX   = placement.x * scale + offset.width  + (placement.width  * scale) / 2
        let centerY   = placement.y * scale + offset.height + (placement.height * scale) / 2
        let isDragging = activeDrag?.id == placement.id
        let dragOffset = isDragging ? (activeDrag?.offset ?? .zero) : .zero

        return ClipCard(
            clip: clip,
            onTap:    { onCopyClip(clip) },
            onDelete: { deletePlacement(placement) }
        )
        .frame(width: placement.width, height: placement.height)
        .scaleEffect(scale * (isDragging ? 1.06 : 1.0))
        .frame(width: placement.width * scale, height: placement.height * scale)
        .shadow(
            color: .black.opacity(isDragging ? 0.28 : 0),
            radius: isDragging ? 18 : 0,
            y: isDragging ? 8 : 0
        )
        .offset(x: dragOffset.width, y: dragOffset.height)
        .gesture(cardDragGesture(for: placement))
        .position(x: centerX, y: centerY)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isDragging)
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                canvasOffset = CGSize(
                    width:  baseOffset.width  + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in baseOffset = canvasOffset }
    }

    private func pinchGesture(in geo: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = (baseScale * value).clamped(to: 0.2...4.0)
                let cx = geo.size.width  / 2
                let cy = geo.size.height / 2
                canvasOffset = CGSize(
                    width:  cx - (cx - baseOffset.width)  * next / baseScale,
                    height: cy - (cy - baseOffset.height) * next / baseScale
                )
                canvasScale = next
            }
            .onEnded { _ in
                baseScale  = canvasScale
                baseOffset = canvasOffset
            }
    }

    private func cardDragGesture(for placement: CanvasPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in activeDrag = (placement.id, value.translation) }
            .onEnded { value in
                placement.x += value.translation.width  / canvasScale
                placement.y += value.translation.height / canvasScale
                activeDrag = nil
            }
    }

    // MARK: - Zoom

    private func handleZoom(_ cmd: ZoomCommand, in geo: GeometryProxy) {
        let cx = geo.size.width  / 2
        let cy = geo.size.height / 2
        switch cmd {
        case .zoomIn:
            let next = min(baseScale * 1.35, 4.0)
            canvasOffset = CGSize(
                width:  cx - (cx - baseOffset.width)  * next / baseScale,
                height: cy - (cy - baseOffset.height) * next / baseScale
            )
            canvasScale = next; baseScale = next; baseOffset = canvasOffset
        case .zoomOut:
            let next = max(baseScale / 1.35, 0.2)
            canvasOffset = CGSize(
                width:  cx - (cx - baseOffset.width)  * next / baseScale,
                height: cy - (cy - baseOffset.height) * next / baseScale
            )
            canvasScale = next; baseScale = next; baseOffset = canvasOffset
        case .recenter:
            canvasOffset = .zero; canvasScale = 1.0
            baseOffset = .zero;   baseScale  = 1.0
        }
    }

    // MARK: - Actions

    private func deletePlacement(_ placement: CanvasPlacement) {
        context.delete(placement)
        workspace.updatedAt = Date()
    }
}

private struct EmptyCanvasHint: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap Paste to add your first clip")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 2: Build — should now only have errors in ClipCard, CanvasToolbar, CanvasTopBar**

Press ⌘B. `CanvasView` should compile clean.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Canvas/CanvasView.swift
git commit -m "feat: remove select mode from CanvasView, add zoom command, drag scale/shadow"
```

---

## Task 3: Sticky note ClipCard

**Files:**
- Modify: `ClipCanvas/Views/Canvas/ClipCard.swift`

- [ ] **Step 1: Rewrite ClipCard.swift**

Remove `isSelected`, `isSelectMode`, `onLongPress`. Remove the footer (age, origin). Remove the selection ring overlay. The card is now a pure sticky note: colored background, text content, a subtle resize icon in the bottom-right corner.

```swift
import SwiftUI
import UIKit

struct ClipCard: View {
    let clip: Clip
    let onTap: () -> Void
    let onDelete: () -> Void

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

// MARK: - Preview

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

- [ ] **Step 2: Build — CanvasView.swift should now compile cleanly since ClipCard interface matches**

Press ⌘B. Confirm `CanvasView.swift` and `ClipCard.swift` are error-free.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Canvas/ClipCard.swift
git commit -m "feat: sticky note cards — remove footer and selection chrome"
```

---

## Task 4: Canvas toolbar redesign

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasToolbar.swift`

- [ ] **Step 1: Rewrite CanvasToolbar.swift**

Key changes:
- Add `onZoomIn`, `onZoomOut`, `onRecenter` callbacks
- Mode button active background: `Circle()` instead of `RoundedRectangle`
- All buttons: 44×44pt frame (minimum touch target)
- Toolbar is a large, wide, expressive pill — wider buttons with comfortable spacing
- Background: iOS 26 liquid glass via `.glassEffect()` (falls back to `.regularMaterial` pre-iOS 26)
- Bottom padding 8pt: sits right at safe area boundary (content respects safe area; material can extend behind home indicator via the background modifier trick)

```swift
import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let onPaste: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onRecenter: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Zoom group
            toolButton("minus.magnifyingglass", action: onZoomOut)
            toolButton("scope", action: onRecenter)
            toolButton("plus.magnifyingglass", action: onZoomIn)

            divider

            // Mode group
            modeButton("hand.point.up.left", for: .pan)
            modeButton("pencil.tip",         for: .draw)

            divider

            // Paste
            toolButton("doc.on.clipboard", action: onPaste)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(toolbarBackground, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Buttons

    private func modeButton(_ icon: String, for target: CanvasMode) -> some View {
        Button { mode = target } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(mode == target ? .white : .primary)
                .frame(width: 46, height: 46)
                .background(
                    mode == target ? Color.accentColor : Color.clear,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: mode == target)
    }

    private func toolButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 26)
            .padding(.horizontal, 6)
    }

    // MARK: - Background

    @ViewBuilder
    private var toolbarBackground: some View {
        if #available(iOS 26, *) {
            // Liquid glass — use the new GlassEffect background
            // Replace `.regularMaterial` with `.glassEffect()` once API is confirmed
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color.clear.background(.regularMaterial)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()
        VStack {
            Spacer()
            CanvasToolbar(
                mode: .constant(.pan),
                onPaste: {},
                onZoomIn: {},
                onZoomOut: {},
                onRecenter: {}
            )
        }
    }
}
```

> **iOS 26 liquid glass note:** The `.background(.ultraThinMaterial)` in the `@available(iOS 26)` branch is a placeholder. When you have confirmed the exact `GlassEffect` API (likely `.glassEffect(.regular)` or `.background(.glass, in: Capsule())`), swap the `toolbarBackground` view for the native glass modifier. The shape and padding are already correct.

- [ ] **Step 2: Remove the `.padding(.bottom, 16)` from CanvasContainerView**

In `CanvasContainerView.swift`, the `CanvasToolbar` call no longer needs external bottom padding — the toolbar handles its own 8pt internal padding. The VStack naturally positions the toolbar above the safe area bottom. The toolbar's `.padding(.bottom, 8)` gives breathing room above the home indicator.

The `CanvasToolbar(...)` call in the VStack inside `CanvasContainerView` should have no extra padding modifier (the toolbar self-pads).

Open `CanvasContainerView.swift` and confirm the toolbar section looks like:

```swift
Spacer()

CanvasToolbar(
    mode: $mode,
    onPaste: paste,
    onZoomIn:  { zoomCommand = .zoomIn },
    onZoomOut: { zoomCommand = .zoomOut },
    onRecenter: { zoomCommand = .recenter }
)
```

(No `.padding(.bottom, 16)` on the toolbar call — it was already removed when you rewrote the file in Task 1.)

- [ ] **Step 3: Build and run in Simulator**

Press ⌘R. Verify:
- Toolbar appears at bottom above home indicator
- Pan and draw mode buttons highlight with a filled circle (not rounded rect) when active
- Zoom In / Zoom Out / Scope buttons are visible
- All buttons have comfortable 46×46 touch areas

- [ ] **Step 4: Commit**

```bash
git add ClipCanvas/Views/Canvas/CanvasToolbar.swift
git commit -m "feat: toolbar redesign — larger buttons, circular mode highlight, zoom controls, liquid glass"
```

---

## Task 5: Canvas top bar — inline rename + workspace context menu

**Files:**
- Modify: `ClipCanvas/Views/Canvas/CanvasTopBar.swift`

- [ ] **Step 1: Rewrite CanvasTopBar.swift**

Remove the entire select-mode branch (`if mode == .select { ... } else { ... }`). The bar is now always in "normal" mode. Replace `selectedCount`, `mode`, `onExitSelectMode`, `onDeleteSelected`, `onCopySelected` parameters with rename state bindings + action callbacks + `onClearAll`.

The workspace name becomes a `TextField` when `isRenaming == true`, otherwise a tappable `Text`. A `Menu` button on the trailing side gives workspace-level actions.

```swift
import SwiftUI

struct CanvasTopBar: View {
    let workspaceName: String
    @Binding var isRenaming: Bool
    @Binding var renameText: String
    var renameFocused: FocusState<Bool>.Binding
    let onToggleSidebar: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Sidebar toggle
            Button(action: onToggleSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            // Workspace name / rename field
            if isRenaming {
                TextField("Workspace name", text: $renameText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .focused(renameFocused)
                    .onSubmit { onCommitRename() }
                    .frame(maxWidth: 200)
            } else {
                Text(workspaceName)
                    .font(.headline)
                    .onTapGesture { onBeginRename() }
            }

            Spacer()

            // Workspace context menu
            Menu {
                Button("Rename Workspace", systemImage: "pencil") { onBeginRename() }
                Divider()
                Button("Clear Canvas", systemImage: "trash", role: .destructive) { onClearAll() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(.regularMaterial, ignoresSafeAreaEdges: .top)
    }
}
```

- [ ] **Step 2: Build — all canvas files should now compile clean**

Press ⌘B. Expect zero errors across the Canvas view group.

- [ ] **Step 3: Run in Simulator and verify end-to-end**

Expected behavior:
- Tap workspace name → field becomes editable, keyboard appears
- Submit/tap elsewhere (dismiss keyboard) → commits new name
- Ellipsis menu → shows "Rename Workspace" and "Clear Canvas"
- "Clear Canvas" removes all cards from the canvas
- Toolbar: zoom in/out animate the canvas; scope resets scale and position
- Cards: tapping copies to clipboard and shows "Copied" banner
- Cards: no footer, just sticky note content + small resize icon corner
- Cards: dragging lifts card (scale + shadow), drops cleanly on release

- [ ] **Step 4: Commit**

```bash
git add ClipCanvas/Views/Canvas/CanvasTopBar.swift
git commit -m "feat: canvas topbar — inline workspace rename and context menu"
```

---

## Self-review checklist

**Spec coverage:**

| Requirement | Task |
|-------------|------|
| No auto-clipboard add to canvas | Task 1 — `watchClipboard` removed |
| No checkbox select mode | Tasks 1–2 — `CanvasMode.select` gone |
| Cards copy on tap | Task 2 — card tap always calls `onCopyClip` |
| Sticky note cards (no footer) | Task 3 |
| Resize icon in card corner | Task 3 |
| Drag shadow + scale animation | Task 2 |
| Circular mode button highlight | Task 4 |
| Buttons ≥44pt touch target | Task 4 |
| Zoom in / out / recenter | Tasks 2 + 4 |
| Toolbar uses bottom safe area | Task 4 (8pt clearance, no extra gap) |
| Liquid glass toolbar | Task 4 (glass background, iOS 26 placeholder) |
| Large expressive toolbar | Task 4 (46pt buttons, wide pill) |
| Workspace rename in topbar | Task 5 |
| Context menu button in topbar | Task 5 |
| Clear all canvas action | Tasks 1 + 5 |

**No placeholders found.**

**Type consistency:** `ZoomCommand` defined in Task 1 (`CanvasMode.swift`), used in Tasks 2, 4. `ClipCard(clip:onTap:onDelete:)` defined in Task 3, used in Task 2. ✓
