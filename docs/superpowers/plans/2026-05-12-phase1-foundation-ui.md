# ClipCanvas Phase 1 — Foundation UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the visual and structural skeleton of ClipCanvas — the adaptive navigation shell, sticky-note clip cards, infinite 2D canvas, and basic clipboard capture — across iPhone, iPad, and Mac. No AI. No transforms. No drawing. Just: capture → see → arrange.

**Architecture:** Three SwiftData models (`Clip`, `Workspace`, `CanvasPlacement`). Two stateless services (`ClipboardService`, `SensitivityService`). One `NavigationSplitView` root that collapses on iPhone, shows two columns on iPad, and three columns on Mac. All platform adaptation is declarative — no `#if os()` in views, only in services where AppKit/UIKit diverge.

**Tech Stack:** SwiftUI, SwiftData, `NavigationSplitView`, `MagnificationGesture`, `DragGesture`. iOS 26 / macOS 26 minimum deployment target.

---

## Platform mockups

### iPhone — canvas-first, sidebar slides in
```
┌─────────────────────┐
│ ≡  Canvas 1    [+] │  ← toolbar: sidebar toggle, paste
│─────────────────────│
│  · · · · · · · · · │
│  ·  ┌──────────┐  ·│
│  ·  │🟡 clip   │  ·│  ← sticky note cards
│  ·  │  text    │  ·│    user-chosen color
│  ·  └──────────┘  ·│
│  ·  · · ┌──────┐ ·│
│  ·  · · │🩷 url │ ·│
│  ·  · · └──────┘ ·│
│  · · · · · · · · · │  ← dot grid bg
└─────────────────────┘
  ↑ sidebar swipes in from left: all clips + workspace switcher
```

### iPad — NavigationSplitView two-column
```
┌────────┬──────────────────────────────┐
│Clips   │                              │
│────────│     · · · · · · · · · · ·   │
│Today   │     ·  ┌──────┐ · · · · ·   │
│  clip1 │     ·  │🟡    │ · · · · ·   │
│  clip2 │     ·  └──────┘ · · · · ·   │
│────────│     ·  · ┌──────┐ · · · ·   │
│Yest.   │     ·  · │🩷    │ · · · ·   │
│  clip3 │     ·  · └──────┘ · · · ·   │
│────────│                              │
│[+WS]   │   [≡ Canvas 1 ▼]  [paste]   │
└────────┴──────────────────────────────┘
```

### Mac — NavigationSplitView three-column
```
┌──────────┬──────────┬───────────────────────────────┐
│Workspaces│  Clips   │                               │
│──────────│──────────│     · · · · · · · · · ·      │
│● Canvas 1│ Today    │     ·  ┌──────┐ · · · ·      │
│  Canvas 2│  clip1   │     ·  │🟡    │ · · · ·      │
│──────────│  clip2   │     ·  └──────┘             │
│ [+ New]  │ Yest.    │     · · · · · · · · · ·      │
│          │  clip3   │                               │
│          │──────────│  [Canvas 1 ▼]  [Paste] [⚙]   │
└──────────┴──────────┴───────────────────────────────┘
```

---

## Sticky note color palette

Clips look like Post-it notes. Seven colors, all soft pastels:

| Name | Hex (light) | Feel |
|------|------------|------|
| `.cloud` | `#F5F5F0` | Neutral, default |
| `.banana` | `#FFF176` | Classic yellow Post-it |
| `.flamingo` | `#FFABAB` | Warm pink |
| `.sage` | `#B5EAD7` | Soft green |
| `.sky` | `#AED6F1` | Light blue |
| `.lavender` | `#D7BDE2` | Light purple |
| `.peach` | `#FFDAC1` | Warm orange |

Cards in dark mode use the same hue shifted darker (+saturation, -brightness). Text is always `.primary` (auto black/white). Footer metadata is `.secondary`.

---

## File map

```
Delete:
  ClipCanvas/Item.swift
  ClipCanvas/ContentView.swift

Create/Replace:
  ClipCanvas/ClipCanvasApp.swift          ← ModelContainer + entry point
  ClipCanvas/Models/Clip.swift            ← Clip @Model (ClipType, CardColor, ClipOrigin)
  ClipCanvas/Models/Workspace.swift       ← Workspace + CanvasPlacement @Model
  ClipCanvas/App/AppBootstrap.swift       ← ensure first workspace exists
  ClipCanvas/Services/ClipboardService.swift
  ClipCanvas/Services/SensitivityService.swift
  ClipCanvas/Views/RootView.swift         ← NavigationSplitView root
  ClipCanvas/Views/Sidebar/SidebarView.swift
  ClipCanvas/Views/Canvas/CanvasView.swift
  ClipCanvas/Views/Canvas/ClipCard.swift
  ClipCanvas/Views/Common/FeedbackBanner.swift

Tests:
  ClipCanvasTests/ClipModelTests.swift
  ClipCanvasTests/SensitivityServiceTests.swift
```

**Responsibilities:**
- `Clip` — content, type, color, origin, sensitivity, pin. No canvas position.
- `Workspace` — name, active flag, sort order. No content.
- `CanvasPlacement` — x, y, width, height, color override. Points at a `Clip`.
- `ClipboardService` — read clipboard, write clip, read fingerprint. Pure static functions.
- `SensitivityService` — detect PII/secrets in text. Pure static functions.
- `RootView` — `NavigationSplitView` only. No business logic.
- `SidebarView` — `@Query` clips, workspace list. No canvas logic.
- `CanvasView` — pan/zoom state, places `ClipCard`s. No data access beyond the workspace it receives.
- `ClipCard` — renders one card. No state. Props in, events out.

---

## Task 1 — Clean up template

**Files:**
- Delete: `ClipCanvas/Item.swift`, `ClipCanvas/ContentView.swift`
- Modify: `ClipCanvas/ClipCanvasApp.swift`

- [ ] **Step 1: Delete template files**

```bash
rm /Users/niclas/SwiftProjects/ClipCanvas/ClipCanvas/Item.swift
rm /Users/niclas/SwiftProjects/ClipCanvas/ClipCanvas/ContentView.swift
```

- [ ] **Step 2: Add Unit Test target (if not present)**

In Xcode: File → New → Target → Unit Testing Bundle → name `ClipCanvasTests` → target `ClipCanvas`.

- [ ] **Step 3: Replace ClipCanvasApp.swift with a stub that builds**

```swift
// ClipCanvas/ClipCanvasApp.swift
import SwiftUI

@main
struct ClipCanvasApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Loading…")
        }
    }
}
```

- [ ] **Step 4: Build**

Cmd+B. Expected: build succeeds, no errors.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/ClipCanvasApp.swift
git rm ClipCanvas/Item.swift ClipCanvas/ContentView.swift
git commit -m "chore: remove Xcode template boilerplate"
```

---

## Task 2 — Clip model

**Files:**
- Create: `ClipCanvas/Models/Clip.swift`
- Create: `ClipCanvasTests/ClipModelTests.swift`

KISS principle at work: `Clip` has no canvas position (that's `CanvasPlacement`'s job), no relationship to workspace (a clip can be anywhere), and no AI data (Phase 2). One class, one responsibility.

`CardColor` lives here, not in `Workspace`, because the color is an attribute of the clip's appearance, and the clip carries a *default* color preference. A `CanvasPlacement` can override it later if needed.

- [ ] **Step 1: Write failing tests**

```swift
// ClipCanvasTests/ClipModelTests.swift
import Testing
import Foundation
@testable import ClipCanvas

@Suite struct ClipModelTests {

    @Test func defaultColorIsCloud() {
        let clip = Clip(content: "hello", origin: .clipboard)
        #expect(clip.color == .cloud)
    }

    @Test func urlDetection() {
        let clip = Clip(content: "https://apple.com", origin: .clipboard)
        #expect(clip.type == .url)
    }

    @Test func codeDetection() {
        let clip = Clip(content: "func foo() {\n    return 42\n}", origin: .clipboard)
        #expect(clip.type == .code)
    }

    @Test func plainTextDetection() {
        let clip = Clip(content: "Buy oat milk", origin: .clipboard)
        #expect(clip.type == .text)
    }

    @Test func imageTypeWhenDataPresent() {
        let clip = Clip(content: "", imageData: Data([0x89, 0x50]), imageUTI: "public.png", origin: .clipboard)
        #expect(clip.type == .image)
    }

    @Test func previewMasksPrivateContent() {
        let clip = Clip(content: "hunter2", origin: .clipboard, sensitivity: .privateContent)
        let preview = clip.preview
        #expect(preview.allSatisfy { $0 == "•" })
    }

    @Test func previewShowsTextForNormalContent() {
        let clip = Clip(content: "Hello world", origin: .clipboard)
        #expect(clip.preview == "Hello world")
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

Cmd+U. Expected: compile error, `Clip` not defined yet.

- [ ] **Step 3: Create Clip.swift**

```swift
// ClipCanvas/Models/Clip.swift
import Foundation
import SwiftData

// MARK: - Supporting enums

enum ClipType: String, Codable, CaseIterable {
    case text, url, code, image

    var icon: String {
        switch self {
        case .text:  return "doc.text"
        case .url:   return "link"
        case .code:  return "curlybraces"
        case .image: return "photo"
        }
    }
}

enum ClipOrigin: String, Codable, CaseIterable {
    case clipboard  // captured automatically or via paste
    case typed      // user typed directly in app
    case shared     // received via Share sheet

    var label: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .typed:     return "Typed"
        case .shared:    return "Shared"
        }
    }
}

enum Sensitivity: String, Codable {
    case normal
    case sensitive       // PII (email, SSN, credit card)
    case privateContent  // secrets (password, api_key, token)
}

enum CardColor: String, Codable, CaseIterable {
    case cloud, banana, flamingo, sage, sky, lavender, peach

    var label: String {
        switch self {
        case .cloud:    return "Cloud"
        case .banana:   return "Banana"
        case .flamingo: return "Flamingo"
        case .sage:     return "Sage"
        case .sky:      return "Sky"
        case .lavender: return "Lavender"
        case .peach:    return "Peach"
        }
    }
}

// MARK: - Model

@Model
final class Clip {
    var id: UUID = UUID()
    var content: String
    var imageData: Data?
    var imageUTI: String?
    var type: ClipType
    var origin: ClipOrigin
    var sensitivity: Sensitivity
    var color: CardColor
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        content: String,
        imageData: Data? = nil,
        imageUTI: String? = nil,
        origin: ClipOrigin,
        sensitivity: Sensitivity = .normal,
        color: CardColor = .cloud
    ) {
        self.content = content
        self.imageData = imageData
        self.imageUTI = imageUTI
        self.origin = origin
        self.sensitivity = sensitivity
        self.color = color
        self.type = Self.detect(content: content, imageData: imageData)
    }

    // Computed — not stored, derived on demand
    var isMasked: Bool { sensitivity != .normal }

    var preview: String {
        guard !isMasked else {
            return String(repeating: "•", count: min(max(content.count, 6), 24))
        }
        if type == .image { return content.isEmpty ? "Image" : content }
        return content
    }

    // MARK: - Type detection

    static func detect(content: String, imageData: Data?) -> ClipType {
        if imageData != nil { return .image }
        if looksLikeURL(content) { return .url }
        if looksLikeCode(content) { return .code }
        return .text
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        guard let url = URL(string: text) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return false }
        let keywords = [
            "func ", "class ", "struct ", "enum ", "import ",
            "def ", "async ", "function ", "const ", "public ",
            "private ", "#include", "SELECT ", "->", "=>"
        ]
        let hits = keywords.filter { text.contains($0) }.count
        let hasIndent = lines.dropFirst().contains { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        return hits >= 2 || (hits >= 1 && hasIndent)
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Cmd+U. Expected: all 7 `ClipModelTests` pass.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/Models/Clip.swift ClipCanvasTests/ClipModelTests.swift
git commit -m "feat: add Clip model with type detection and color palette"
```

---

## Task 3 — Workspace + CanvasPlacement model

**Files:**
- Create: `ClipCanvas/Models/Workspace.swift`

KISS: `Workspace` is just a named container. `CanvasPlacement` is purely positional metadata — it says where a clip sits on a specific workspace's canvas. A clip placed on two workspaces has two placements.

- [ ] **Step 1: Create Workspace.swift**

```swift
// ClipCanvas/Models/Workspace.swift
import Foundation
import SwiftData

@Model
final class Workspace {
    var id: UUID = UUID()
    var name: String
    var isActive: Bool = false
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \CanvasPlacement.workspace)
    var placements: [CanvasPlacement] = []

    init(name: String, sortIndex: Int = 0, isActive: Bool = false) {
        self.name = name
        self.sortIndex = sortIndex
        self.isActive = isActive
    }

    // Staggers new cards so they don't all land on top of each other
    func nextPosition() -> CGPoint {
        let i = Double(placements.count)
        return CGPoint(
            x: 200 + i.truncatingRemainder(dividingBy: 6) * 30,
            y: 180 + i.truncatingRemainder(dividingBy: 8) * 24
        )
    }

    @discardableResult
    func place(clip: Clip, at position: CGPoint? = nil) -> CanvasPlacement {
        let pos = position ?? nextPosition()
        let p = CanvasPlacement(clip: clip, x: pos.x, y: pos.y)
        p.workspace = self
        placements.append(p)
        updatedAt = Date()
        return p
    }
}

@Model
final class CanvasPlacement {
    var id: UUID = UUID()
    var workspace: Workspace?
    var clip: Clip?           // nullify on clip delete — placement disappears naturally
    var x: Double
    var y: Double
    var width: Double = 220
    var height: Double = 150
    var createdAt: Date = Date()

    init(clip: Clip?, x: Double, y: Double) {
        self.clip = clip
        self.x = x
        self.y = y
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Models/Workspace.swift
git commit -m "feat: add Workspace and CanvasPlacement models"
```

---

## Task 4 — Services

**Files:**
- Create: `ClipCanvas/Services/SensitivityService.swift`
- Create: `ClipCanvas/Services/ClipboardService.swift`
- Create: `ClipCanvasTests/SensitivityServiceTests.swift`

Both are `enum` with static methods — no instances, no state. KISS. No protocol abstraction needed at this stage; the functions are pure and trivially unit-testable.

- [ ] **Step 1: Write failing tests**

```swift
// ClipCanvasTests/SensitivityServiceTests.swift
import Testing
@testable import ClipCanvas

@Suite struct SensitivityServiceTests {

    @Test func normalText() {
        #expect(SensitivityService.detect("Buy oat milk") == .normal)
    }

    @Test func emailAddress() {
        #expect(SensitivityService.detect("contact me at foo@bar.com") == .sensitive)
    }

    @Test func socialSecurityNumber() {
        #expect(SensitivityService.detect("SSN: 123-45-6789") == .sensitive)
    }

    @Test func creditCard() {
        #expect(SensitivityService.detect("card 4111 1111 1111 1111 exp 12/28") == .sensitive)
    }

    @Test func passwordKeyword() {
        #expect(SensitivityService.detect("password: hunter2") == .privateContent)
    }

    @Test func apiKeyKeyword() {
        #expect(SensitivityService.detect("api_key=abc123secretxyz") == .privateContent)
    }

    @Test func tokenKeyword() {
        #expect(SensitivityService.detect("bearer token: eyJhbGciOiJIUzI") == .privateContent)
    }

    @Test func privateKeywordWinsOverPII() {
        // if text has both a password keyword AND an email, privateContent wins
        #expect(SensitivityService.detect("password for foo@bar.com is hunter2") == .privateContent)
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

Cmd+U. Expected: compile error.

- [ ] **Step 3: Create SensitivityService.swift**

```swift
// ClipCanvas/Services/SensitivityService.swift
import Foundation

enum SensitivityService {

    private static let privateKeywords = [
        "password", "passwd", "secret", "api_key", "apikey",
        "token", "private_key", "access_key", "auth_key", "bearer",
    ]

    // Pre-compiled regexes: SSN, credit card, email
    private static let piiPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#),
        try! NSRegularExpression(pattern: #"\b(?:\d[ -]?){13,19}\b"#),
        try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#),
    ]

    static func detect(_ text: String) -> Sensitivity {
        let lower = text.lowercased()
        // Private keywords checked first — higher severity wins
        if privateKeywords.contains(where: { lower.contains($0) }) {
            return .privateContent
        }
        let range = NSRange(text.startIndex..., in: text)
        if piiPatterns.contains(where: { $0.firstMatch(in: text, range: range) != nil }) {
            return .sensitive
        }
        return .normal
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Cmd+U. Expected: all 8 `SensitivityServiceTests` pass.

- [ ] **Step 5: Create ClipboardService.swift**

```swift
// ClipCanvas/Services/ClipboardService.swift
import UIKit

// A value representing what's on the clipboard right now
enum ClipboardContent {
    case text(String)
    case image(Data, uti: String)

    // Used to detect when clipboard changes without storing the full content
    var fingerprint: String {
        switch self {
        case .text(let s):        return "t:\(s.hashValue)"
        case .image(let d, _):    return "i:\(d.count):\(d.hashValue)"
        }
    }
}

enum ClipboardService {

    static func readContent() -> ClipboardContent? {
        let pb = UIPasteboard.general
        if let image = pb.image, let data = image.pngData() {
            return .image(data, uti: "public.png")
        }
        if let text = pb.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        return nil
    }

    static func write(clip: Clip) {
        if clip.type == .image, let data = clip.imageData, let image = UIImage(data: data) {
            UIPasteboard.general.image = image
        } else {
            UIPasteboard.general.string = clip.content
        }
    }

    static func writeString(_ string: String) {
        UIPasteboard.general.string = string
    }
}

// Factory extension — one canonical way to create a Clip from clipboard content
extension Clip {
    static func make(from content: ClipboardContent, origin: ClipOrigin) -> Clip {
        switch content {
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = trimmed.isEmpty ? text : trimmed
            let sensitivity = SensitivityService.detect(body)
            return Clip(content: body, origin: origin, sensitivity: sensitivity)
        case .image(let data, let uti):
            return Clip(content: "", imageData: data, imageUTI: uti, origin: origin)
        }
    }
}
```

- [ ] **Step 6: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 7: Commit**

```bash
git add ClipCanvas/Services/SensitivityService.swift \
        ClipCanvas/Services/ClipboardService.swift \
        ClipCanvasTests/SensitivityServiceTests.swift
git commit -m "feat: add SensitivityService and ClipboardService"
```

---

## Task 5 — App bootstrap + ModelContainer

**Files:**
- Create: `ClipCanvas/App/AppBootstrap.swift`
- Modify: `ClipCanvas/ClipCanvasApp.swift`

- [ ] **Step 1: Create AppBootstrap.swift**

```swift
// ClipCanvas/App/AppBootstrap.swift
import SwiftData
import Foundation

enum AppBootstrap {
    // Ensures at least one workspace exists and exactly one is active.
    // Call once at app launch from the SwiftData context.
    static func ensureActiveWorkspace(in context: ModelContext) {
        let all = (try? context.fetch(
            FetchDescriptor<Workspace>(sortBy: [SortDescriptor(\Workspace.sortIndex)])
        )) ?? []

        if all.isEmpty {
            let ws = Workspace(name: "Canvas", sortIndex: 0, isActive: true)
            context.insert(ws)
            return
        }

        let active = all.filter(\.isActive)
        if active.isEmpty {
            all[0].isActive = true
        } else if active.count > 1 {
            // Repair state: keep only the first active
            for ws in active.dropFirst() { ws.isActive = false }
        }
    }
}
```

- [ ] **Step 2: Replace ClipCanvasApp.swift**

```swift
// ClipCanvas/ClipCanvasApp.swift
import SwiftUI
import SwiftData

@main
struct ClipCanvasApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Clip.self, Workspace.self, CanvasPlacement.self)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
```

Note: `RootView` is a stub right now — we create it next.

- [ ] **Step 3: Create RootView stub**

```swift
// ClipCanvas/Views/RootView.swift
import SwiftUI

struct RootView: View {
    var body: some View {
        Text("RootView — coming in Task 6")
    }
}
```

- [ ] **Step 4: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/App/AppBootstrap.swift ClipCanvas/ClipCanvasApp.swift ClipCanvas/Views/RootView.swift
git commit -m "feat: configure ModelContainer and AppBootstrap"
```

---

## Task 6 — ClipCard (sticky note)

**Files:**
- Create: `ClipCanvas/Views/Canvas/ClipCard.swift`
- Create: `ClipCanvas/Views/Common/FeedbackBanner.swift`

This is a pure presentational component. It receives a `Clip`, its selection state, and callbacks. No `@Environment`, no `modelContext`. It just renders. This is the most-visible UI in the whole app, so get it right before wiring it to real data.

**Card anatomy:**
```
┌────────────────────┐  ← CardColor background + shadow
│                    │    rounded corners (14pt)
│  preview text      │  ← .body font, 6 lines max
│  here...           │
│                    │
│────────────────────│  ← 1pt separator, slightly darker
│ 🔗  link  2m ago  │  ← type icon, origin, relative time
└────────────────────┘

Selected state: 2.5pt accent-color ring
```

- [ ] **Step 1: Create ClipCard.swift**

```swift
// ClipCanvas/Views/Canvas/ClipCard.swift
import SwiftUI

struct ClipCard: View {
    let clip: Clip
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Divider()
                .background(clip.color.dividerColor)
            footer
        }
        .background(clip.color.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(selectionRing)
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.08), radius: isSelected ? 12 : 5, y: isSelected ? 4 : 2)
        .onTapGesture { onTap() }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                ClipboardService.write(clip: clip)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }

    // MARK: - Subviews

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
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: clip.type.icon)
                .font(.system(size: 10))
            Text(clip.origin.label)
                .font(.system(size: 10))
            Spacer()
            Text(clip.createdAt, style: .relative)
                .font(.system(size: 10))
        }
        .foregroundStyle(clip.color.footerColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var selectionRing: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.accentColor, lineWidth: isSelected ? 2.5 : 0)
    }
}

// MARK: - CardColor visual properties

extension CardColor {
    var background: Color {
        switch self {
        case .cloud:    return Color(red: 0.96, green: 0.96, blue: 0.94)
        case .banana:   return Color(red: 1.00, green: 0.95, blue: 0.46)
        case .flamingo: return Color(red: 1.00, green: 0.67, blue: 0.67)
        case .sage:     return Color(red: 0.71, green: 0.92, blue: 0.84)
        case .sky:      return Color(red: 0.68, green: 0.84, blue: 0.95)
        case .lavender: return Color(red: 0.84, green: 0.74, blue: 0.89)
        case .peach:    return Color(red: 1.00, green: 0.85, blue: 0.76)
        }
    }

    // Slightly darker version of the background for the divider
    var dividerColor: Color { background.opacity(0.6) }

    // Dark enough to read on any card color
    var footerColor: Color { Color.black.opacity(0.45) }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ClipCard(
            clip: {
                let c = Clip(content: "Buy oat milk and check the PR before standup tomorrow morning.", origin: .clipboard)
                return c
            }(),
            isSelected: false,
            onTap: {},
            onDelete: {}
        )
        .frame(width: 220)

        ClipCard(
            clip: {
                let c = Clip(content: "https://developer.apple.com/documentation/swiftui", origin: .clipboard)
                return c
            }(),
            isSelected: true,
            onTap: {},
            onDelete: {}
        )
        .frame(width: 220)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
```

- [ ] **Step 2: Create FeedbackBanner.swift**

```swift
// ClipCanvas/Views/Common/FeedbackBanner.swift
import SwiftUI

// Transient feedback pill — appears at top of screen for 1.7s then fades out.
// Usage: overlay(alignment: .top) { FeedbackBanner(message: feedback) }
struct FeedbackBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 4, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

- [ ] **Step 3: Open Xcode Canvas preview for ClipCard**

In Xcode, open `ClipCard.swift` and press Cmd+Option+Return to open the preview canvas. Verify:
- `.cloud` card looks neutral/white
- The selected card has a blue ring
- Footer shows type icon, origin, and "just now"
- Text wraps cleanly at 6 lines

- [ ] **Step 4: Commit**

```bash
git add ClipCanvas/Views/Canvas/ClipCard.swift ClipCanvas/Views/Common/FeedbackBanner.swift
git commit -m "feat: add ClipCard (sticky note) and FeedbackBanner"
```

---

## Task 7 — CanvasView (infinite 2D canvas)

**Files:**
- Create: `ClipCanvas/Views/Canvas/CanvasView.swift`

The canvas uses a `ZStack` with absolutely-positioned cards. Pan is tracked via `DragGesture` on the background. Zoom is `MagnificationGesture`. Cards move when dragged individually.

KISS: No `UIScrollView`. No `ScrollView`. Pure SwiftUI gesture composition. The canvas coordinate space is fixed; we offset everything by a single `CGPoint` and scale by a single `CGFloat`. This is simple to reason about and simple to extend.

- [ ] **Step 1: Create CanvasView.swift**

```swift
// ClipCanvas/Views/Canvas/CanvasView.swift
import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    @Binding var selectedID: UUID?

    @Environment(\.modelContext) private var context
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var feedback: String?

    private var placements: [CanvasPlacement] { workspace.placements }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dotGrid(in: geo)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedID = nil }
                    .gesture(canvasPanGesture)

                ForEach(placements) { placement in
                    if let clip = placement.clip {
                        positionedCard(placement: placement, clip: clip)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .simultaneousGesture(canvasPinchGesture)
        .overlay(alignment: .top) {
            if let feedback {
                FeedbackBanner(message: feedback).padding(.top, 10)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: feedback != nil)
    }

    // MARK: - Dot grid background

    private func dotGrid(in geo: GeometryProxy) -> some View {
        Canvas { ctx, size in
            let spacing = 28.0 * canvasScale * pinchScale
            // Offset the dot grid so it appears fixed as the canvas pans
            let ox = (canvasOffset.width + dragDelta.width).truncatingRemainder(dividingBy: spacing)
            let oy = (canvasOffset.height + dragDelta.height).truncatingRemainder(dividingBy: spacing)
            var x = ox; while x < size.width + spacing { defer { x += spacing }
                var y = oy; while y < size.height + spacing { defer { y += spacing }
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(.secondary.opacity(0.22))
                    )
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Card positioning

    private func positionedCard(placement: CanvasPlacement, clip: Clip) -> some View {
        let effectiveScale = canvasScale * pinchScale
        let effectiveOffset = CGSize(
            width: canvasOffset.width + dragDelta.width,
            height: canvasOffset.height + dragDelta.height
        )
        let screenX = placement.x * effectiveScale + effectiveOffset.width
        let screenY = placement.y * effectiveScale + effectiveOffset.height

        return ClipCard(
            clip: clip,
            isSelected: selectedID == placement.id,
            onTap: { selectedID = (selectedID == placement.id) ? nil : placement.id },
            onDelete: { deletePlacement(placement) }
        )
        .frame(width: placement.width, height: placement.height)
        .gesture(cardDragGesture(for: placement))
        .position(x: screenX + placement.width / 2, y: screenY + placement.height / 2)
        .scaleEffect(effectiveScale, anchor: .topLeading)
        // Counteract the scaleEffect on the frame so the size stays correct:
        .frame(width: placement.width * effectiveScale, height: placement.height * effectiveScale)
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                canvasOffset.width += value.translation.width
                canvasOffset.height += value.translation.height
            }
    }

    private var canvasPinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                canvasScale = (canvasScale * value).clamped(to: 0.2...4.0)
            }
    }

    private func cardDragGesture(for placement: CanvasPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let scale = canvasScale * pinchScale
                placement.x += value.translation.width / scale
                placement.y += value.translation.height / scale
            }
    }

    // MARK: - Actions

    private func deletePlacement(_ placement: CanvasPlacement) {
        if selectedID == placement.id { selectedID = nil }
        context.delete(placement)
        workspace.updatedAt = Date()
    }

    private func showFeedback(_ msg: String) {
        withAnimation { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Canvas/CanvasView.swift
git commit -m "feat: add infinite 2D canvas with pan, zoom, and card drag"
```

---

## Task 8 — SidebarView

**Files:**
- Create: `ClipCanvas/Views/Sidebar/SidebarView.swift`

The sidebar shows two things: a workspace picker at the top, and a grouped list of all clips below. Tapping a clip adds it to the active canvas.

- [ ] **Step 1: Create SidebarView.swift**

```swift
// ClipCanvas/Views/Sidebar/SidebarView.swift
import SwiftUI
import SwiftData

struct SidebarView: View {
    let workspaces: [Workspace]
    let activeWorkspace: Workspace?
    let onActivateWorkspace: (Workspace) -> Void
    let onCreateWorkspace: () -> Void
    let onPlaceClip: (Clip) -> Void

    @Query(sort: \Clip.createdAt, order: .reverse)
    private var clips: [Clip]

    @State private var search = ""
    @Environment(\.modelContext) private var context

    private var filtered: [Clip] {
        guard !search.isEmpty else { return clips }
        return clips.filter { $0.content.localizedCaseInsensitiveContains(search) }
    }

    // Groups clips by relative time bucket
    private var grouped: [(label: String, clips: [Clip])] {
        let calendar = Calendar.current
        var today: [Clip] = [], yesterday: [Clip] = [], week: [Clip] = [], older: [Clip] = []
        let now = Date()
        for clip in filtered {
            if calendar.isDateInToday(clip.createdAt) { today.append(clip) }
            else if calendar.isDateInYesterday(clip.createdAt) { yesterday.append(clip) }
            else if let ago = calendar.date(byAdding: .day, value: -7, to: now), clip.createdAt > ago { week.append(clip) }
            else { older.append(clip) }
        }
        return [("Today", today), ("Yesterday", yesterday), ("This Week", week), ("Older", older)]
            .filter { !$0.clips.isEmpty }
    }

    var body: some View {
        List {
            workspacePicker
            clipList
        }
        .listStyle(.sidebar)
        .searchable(text: $search, prompt: "Search clips…")
        .navigationTitle("Clips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreateWorkspace) {
                    Label("New Workspace", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Workspace picker

    @ViewBuilder
    private var workspacePicker: some View {
        Section("Workspaces") {
            ForEach(workspaces) { ws in
                Button {
                    onActivateWorkspace(ws)
                } label: {
                    HStack {
                        Image(systemName: ws.isActive ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(ws.isActive ? .accentColor : .secondary)
                        Text(ws.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(ws.placements.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Clip list

    @ViewBuilder
    private var clipList: some View {
        if filtered.isEmpty {
            if clips.isEmpty {
                ContentUnavailableView(
                    "No clips yet",
                    systemImage: "doc.on.clipboard",
                    description: Text("Paste content to add your first clip.")
                )
                .listRowBackground(Color.clear)
            } else {
                ContentUnavailableView.search(text: search)
                    .listRowBackground(Color.clear)
            }
        } else {
            ForEach(grouped, id: \.label) { group in
                Section(group.label) {
                    ForEach(group.clips) { clip in
                        SidebarClipRow(
                            clip: clip,
                            onPlace: { onPlaceClip(clip) }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { context.delete(clip) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sidebar clip row

private struct SidebarClipRow: View {
    let clip: Clip
    let onPlace: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Color swatch
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.color.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(clip.color.background.opacity(0.5), lineWidth: 0.5)
                )
                .frame(width: 8, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.preview)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: clip.type.icon)
                        .font(.caption2)
                    Text(clip.createdAt, style: .relative)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onPlace) {
                Image(systemName: "arrow.right.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Place on canvas")
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Sidebar/SidebarView.swift
git commit -m "feat: add SidebarView with workspace picker and grouped clips list"
```

---

## Task 9 — RootView (NavigationSplitView)

**Files:**
- Modify: `ClipCanvas/Views/RootView.swift`

This is where the three-platform layout comes together. `NavigationSplitView` handles all the platform adaptation: three columns on Mac, two on iPad (with sidebar toggle), collapsing stack on iPhone. We inject no `#if os()` — the view tree is identical across platforms.

- [ ] **Step 1: Replace RootView.swift**

```swift
// ClipCanvas/Views/RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context

    @Query(
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]

    @State private var selectedClip: Clip?           // sidebar selection
    @State private var selectedCardID: UUID?          // canvas selection
    @State private var lastClipboardFingerprint: String?
    @State private var feedback: String?

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
        .task(id: activeWorkspace?.id) { await watchClipboard() }
        .overlay(alignment: .top) {
            if let feedback {
                FeedbackBanner(message: feedback).padding(.top, 10)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: feedback != nil)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        SidebarView(
            workspaces: workspaces,
            activeWorkspace: activeWorkspace,
            onActivateWorkspace: activateWorkspace,
            onCreateWorkspace: createWorkspace,
            onPlaceClip: placeOnCanvas
        )
    }

    // MARK: - Detail (canvas)

    @ViewBuilder
    private var detail: some View {
        if let workspace = activeWorkspace {
            CanvasView(workspace: workspace, selectedID: $selectedCardID)
                .toolbar { canvasToolbar }
        } else {
            ContentUnavailableView(
                "No workspace",
                systemImage: "rectangle.3.group",
                description: Text("Create a workspace to get started.")
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var canvasToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(activeWorkspace?.name ?? "Canvas")
                .font(.headline)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: pasteFromClipboard) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .help("Paste from clipboard (⇧⌘V)")
        }
    }

    // MARK: - Workspace management

    private func activateWorkspace(_ workspace: Workspace) {
        workspaces.forEach { $0.isActive = ($0.id == workspace.id) }
        selectedCardID = nil
    }

    private func createWorkspace() {
        workspaces.forEach { $0.isActive = false }
        let ws = Workspace(
            name: "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        )
        context.insert(ws)
        selectedCardID = nil
    }

    // MARK: - Clip placement

    private func placeOnCanvas(_ clip: Clip) {
        guard let workspace = activeWorkspace else { return }
        workspace.place(clip: clip)
        showFeedback("Placed on canvas")
    }

    // MARK: - Clipboard

    private func pasteFromClipboard() {
        guard let workspace = activeWorkspace else { return }
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        let clip = Clip.make(from: content, origin: .clipboard)
        context.insert(clip)
        let placement = workspace.place(clip: clip)
        selectedCardID = placement.id
        lastClipboardFingerprint = content.fingerprint
        showFeedback("Pasted")
    }

    // Watches clipboard every second. Auto-captures new content.
    private func watchClipboard() async {
        lastClipboardFingerprint = ClipboardService.readContent()?.fingerprint
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard let content = ClipboardService.readContent() else { continue }
            guard content.fingerprint != lastClipboardFingerprint else { continue }
            lastClipboardFingerprint = content.fingerprint
            guard let workspace = activeWorkspace else { continue }
            let clip = Clip.make(from: content, origin: .clipboard)
            context.insert(clip)
            workspace.place(clip: clip)
            showFeedback("Captured from clipboard")
        }
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

- [ ] **Step 2: Build and run in simulator**

Cmd+R on iPhone 16 simulator.

Expected:
- App launches on the canvas (detail view)
- Tap ≡ button to reveal the sidebar (Clips + Workspaces)
- Tap the Paste toolbar button — "Clipboard is empty" feedback pill appears
- Copy text in another app, return to ClipCanvas — "Captured from clipboard" appears and a card is on canvas
- Card is a yellow sticky note with text preview

- [ ] **Step 3: Run on iPad simulator**

Change simulator to iPad Pro 13". Cmd+R.

Expected:
- Sidebar visible on left, canvas on right
- Two-column layout works without any code changes

- [ ] **Step 4: Run on Mac (Mac Catalyst)**

In Xcode scheme selector, choose "My Mac (Mac Catalyst)". Cmd+R.

Expected:
- Three-column NavigationSplitView (Workspaces | Clips | Canvas)
- Toolbar shows "Paste" button with keyboard shortcut ⇧⌘V
- Canvas fills the right panel

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/Views/RootView.swift
git commit -m "feat: implement NavigationSplitView root with clipboard capture across all platforms"
```

---

## Task 10 — Color picker on card

**Files:**
- Modify: `ClipCanvas/Views/Canvas/ClipCard.swift`

Add a color picker to the card's context menu so users can change a clip's sticky note color.

- [ ] **Step 1: Add color picker to ClipCard context menu**

Replace the `contextMenu` in `ClipCard.swift`:

```swift
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
                    .foregroundStyle(color.background)
            }
        }
    }

    Divider()

    Button("Delete", systemImage: "trash", role: .destructive) {
        onDelete()
    }
}
```

- [ ] **Step 2: Run in simulator**

Long-press a card. Expected: context menu appears with "Copy", "Color" submenu (7 colors), and "Delete". Tap a color — card background updates immediately.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Canvas/ClipCard.swift
git commit -m "feat: add color picker to ClipCard context menu"
```

---

## Post-build verification checklist

Run through these flows after all tasks complete:

- [ ] **iPhone**: Copy text → switch to app → card appears on canvas with cloud color
- [ ] **iPhone**: Long-press card → change color to banana → card turns yellow
- [ ] **iPhone**: Swipe ≡ → sidebar opens → tap clip in list → placed on canvas
- [ ] **iPhone**: Pinch canvas → zooms in/out smoothly
- [ ] **iPad**: Sidebar always visible → two-column layout
- [ ] **iPad**: Create second workspace in sidebar → switch between them → canvas is separate per workspace
- [ ] **Mac**: ⇧⌘V pastes from clipboard → card appears
- [ ] **Mac**: Three-column NavigationSplitView with Workspaces | Clips | Canvas

---

## Self-review

**Spec coverage:**
- ✅ KISS — 3 models, 2 services, no ViewModels, no coordinator objects
- ✅ SOLID/SRP — `Clip` owns content logic, `Workspace` owns placement, `CanvasView` owns pan/zoom state, `SidebarView` owns query
- ✅ Multi-platform day one — `NavigationSplitView` handles iPhone/iPad/Mac with zero `#if os()`
- ✅ Sticky note colors — 7 pastel colors on `CardColor`, color picker in context menu
- ✅ iOS 26 system materials — canvas background is `systemBackground`, cards use flat pastels
- ✅ Full 2D canvas on iPhone — same `CanvasView` on all devices
- ✅ AI / transforms / drawing excluded — Phase 2

**Placeholder scan:** None — all steps contain real code.

**Type consistency:**
- `CardColor.background` defined in `ClipCard.swift` — used in `ClipCard` ✅ and `SidebarClipRow` ✅
- `Clip.make(from:origin:)` defined in `ClipboardService.swift` — used in `RootView.pasteFromClipboard` ✅ and `RootView.watchClipboard` ✅
- `Workspace.place(clip:at:)` returns `CanvasPlacement` — used in `RootView` ✅
- `AppBootstrap.ensureActiveWorkspace(in:)` — called in `RootView.task` ✅
- `ClipboardContent.fingerprint` — used in `RootView.watchClipboard` ✅ and `RootView.pasteFromClipboard` ✅
