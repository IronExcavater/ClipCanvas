# ClipCanvas Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild ClipCanvas from scratch with clips as first-class persistent objects, AI transforms that mutate in place (with version history), a unified AI panel for chat + transforms + generation, and drawing as a clip-capture tool.

**Architecture:** Clips exist independently of workspaces — a `CanvasPlacement` is just positional metadata pointing at a `Clip`. Transforms don't create new cards; they append a `ClipVersion` to the clip's history. One `AISession` model replaces both `WorkspaceChatThread` and `TransformRun` — chat, transforms, and AI-generated clips all flow through the same `AIService`.

**Tech Stack:** SwiftUI, SwiftData (iOS 26+), FoundationModels (Apple Intelligence on-device transforms), OpenAI REST API (chat + generation), PencilKit (drawing capture), Vision (handwriting recognition).

---

## File Map

### Delete
- `ClipCanvas/Item.swift`
- `ClipCanvas/ContentView.swift`

### Create
- `ClipCanvas/ClipCanvasApp.swift` ← rewrite (exists, update ModelContainer)
- `ClipCanvas/Models/Clip.swift`
- `ClipCanvas/Models/Workspace.swift`
- `ClipCanvas/Models/AISession.swift`
- `ClipCanvas/Services/SensitivityService.swift`
- `ClipCanvas/Services/ClipboardService.swift`
- `ClipCanvas/Services/AIService.swift`
- `ClipCanvas/Services/DrawRecognitionService.swift`
- `ClipCanvas/App/AppState.swift`
- `ClipCanvas/Views/RootView.swift`
- `ClipCanvas/Views/Clips/ClipsView.swift`
- `ClipCanvas/Views/Clips/ClipDetailView.swift`
- `ClipCanvas/Views/AI/AIPanel.swift`
- `ClipCanvas/Views/Workspace/WorkspaceView.swift`
- `ClipCanvas/Views/Workspace/CanvasSurface.swift`
- `ClipCanvas/Views/Workspace/CanvasCard.swift`
- `ClipCanvas/Views/Draw/DrawCaptureView.swift`
- `ClipCanvas/Views/Settings/SettingsView.swift`
- `ClipCanvasTests/ClipTests.swift`
- `ClipCanvasTests/WorkspaceTests.swift`
- `ClipCanvasTests/SensitivityServiceTests.swift`
- `ClipCanvasTests/AIServiceTests.swift`

---

## Task 1: Clean up template + add test target

**Files:**
- Delete: `ClipCanvas/Item.swift`
- Delete: `ClipCanvas/ContentView.swift`
- Modify: `ClipCanvas/ClipCanvasApp.swift`

- [ ] **Step 1: Delete template files**

In Xcode: select `Item.swift` and `ContentView.swift` → Delete → Move to Trash.

Or via terminal:
```bash
rm /Users/niclas/SwiftProjects/ClipCanvas/ClipCanvas/Item.swift
rm /Users/niclas/SwiftProjects/ClipCanvas/ClipCanvas/ContentView.swift
```

- [ ] **Step 2: Add Unit Test target**

In Xcode: File → New → Target → Unit Testing Bundle. Name it `ClipCanvasTests`. Ensure "Target to be Tested" is `ClipCanvas`.

- [ ] **Step 3: Replace ClipCanvasApp.swift with a placeholder entry point**

```swift
import SwiftUI
import SwiftData

@main
struct ClipCanvasApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Loading…")
        }
    }
}
```

- [ ] **Step 4: Build and verify it compiles**

In Xcode: Cmd+B. Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/ClipCanvasApp.swift
git rm ClipCanvas/Item.swift ClipCanvas/ContentView.swift
git commit -m "chore: remove template files, add test target placeholder"
```

---

## Task 2: Clip model

**Files:**
- Create: `ClipCanvas/Models/Clip.swift`
- Create: `ClipCanvasTests/ClipTests.swift`

The core insight: `Clip.content` always reflects the current version. `Clip.versions` is the full ordered history (oldest → newest). `currentVersionIndex` tracks which version is displayed, defaulting to the latest. Transforms append a new `ClipVersion` and advance the index — no new object is created.

- [ ] **Step 1: Write failing tests**

```swift
// ClipCanvasTests/ClipTests.swift
import Testing
import Foundation
@testable import ClipCanvas

@Suite struct ClipTests {

    @Test func initialClipHasOneVersion() {
        let clip = Clip(content: "Hello", origin: .clipboard)
        #expect(clip.versions.count == 1)
        #expect(clip.content == "Hello")
        #expect(clip.currentVersionIndex == 0)
        #expect(!clip.hasVersionHistory)
    }

    @Test func applyVersionAddsToHistory() {
        let clip = Clip(content: "Hello", origin: .clipboard)
        clip.applyVersion("Distilled", transform: .distill)
        #expect(clip.versions.count == 2)
        #expect(clip.content == "Distilled")
        #expect(clip.currentVersionIndex == 1)
        #expect(clip.hasVersionHistory)
    }

    @Test func navigateVersionBackward() {
        let clip = Clip(content: "Hello", origin: .clipboard)
        clip.applyVersion("Distilled", transform: .distill)
        clip.navigateVersion(by: -1)
        #expect(clip.content == "Hello")
        #expect(clip.currentVersionIndex == 0)
    }

    @Test func navigateVersionClamps() {
        let clip = Clip(content: "Hello", origin: .clipboard)
        clip.navigateVersion(by: -1) // already at 0
        #expect(clip.currentVersionIndex == 0)
    }

    @Test func typeDetectionURL() {
        let clip = Clip(content: "https://apple.com", origin: .clipboard)
        #expect(clip.type == .url)
    }

    @Test func typeDetectionCode() {
        let clip = Clip(content: "func foo() {\n    return bar\n}", origin: .clipboard)
        #expect(clip.type == .code)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Cmd+U. Expected: compile error — `Clip` not defined yet.

- [ ] **Step 3: Create Clip.swift**

```swift
// ClipCanvas/Models/Clip.swift
import Foundation
import SwiftData

enum ClipType: String, Codable, CaseIterable {
    case text, url, code, image, drawing
    var icon: String {
        switch self {
        case .text: "doc.text"
        case .url: "link"
        case .code: "curlybraces"
        case .image: "photo"
        case .drawing: "pencil.tip"
        }
    }
}

enum ClipOrigin: String, Codable, CaseIterable {
    case clipboard     // auto-captured or pasted from system clipboard
    case typed         // user created manually in app
    case aiGenerated   // created by AI (chat reply saved as clip)
    case shared        // received via iOS Share sheet
    case drawn         // created in DrawCaptureView

    var label: String {
        switch self {
        case .clipboard: "Clipboard"
        case .typed: "Typed"
        case .aiGenerated: "AI"
        case .shared: "Shared"
        case .drawn: "Drawing"
        }
    }
}

enum Sensitivity: String, Codable, CaseIterable {
    case normal
    case sensitive       // regex-matched PII (SSN, credit card, email)
    case privateContent  // keyword-matched secrets (password, token, api_key)
}

enum TransformKind: String, Codable, CaseIterable {
    case distill, actionItems, cleanUp, rewrite, title

    var label: String {
        switch self {
        case .distill: "Distill"
        case .actionItems: "Action Items"
        case .cleanUp: "Clean Up"
        case .rewrite: "Rewrite"
        case .title: "Title"
        }
    }
}

struct ClipVersion: Codable, Identifiable {
    var id: UUID = UUID()
    var content: String
    var transformKind: TransformKind?  // nil = original or manual edit
    var createdAt: Date = Date()
}

@Model
final class Clip {
    var id: UUID = UUID()
    var versions: [ClipVersion]         // full ordered history, always ≥ 1 entry
    var currentVersionIndex: Int        // which version is displayed
    var imageData: Data?
    var imageUTI: String?
    var type: ClipType
    var origin: ClipOrigin
    var sensitivity: Sensitivity
    var isPinned: Bool = false
    var expiresAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \CanvasPlacement.clip)
    var placements: [CanvasPlacement] = []

    init(
        content: String,
        imageData: Data? = nil,
        imageUTI: String? = nil,
        origin: ClipOrigin,
        sensitivity: Sensitivity = .normal,
        expiresAt: Date? = nil
    ) {
        let initial = ClipVersion(content: content)
        self.versions = [initial]
        self.currentVersionIndex = 0
        self.imageData = imageData
        self.imageUTI = imageUTI
        self.origin = origin
        self.sensitivity = sensitivity
        self.expiresAt = expiresAt
        self.type = Self.detectType(for: content, imageData: imageData)
    }

    var content: String {
        versions.indices.contains(currentVersionIndex)
            ? versions[currentVersionIndex].content
            : versions.last?.content ?? ""
    }

    var hasVersionHistory: Bool { versions.count > 1 }

    var isMasked: Bool { sensitivity != .normal }

    var preview: String {
        if type == .image { return imageData != nil ? "Image" : content }
        return isMasked ? String(repeating: "•", count: min(max(content.count, 6), 24)) : content
    }

    func applyVersion(_ newContent: String, transform: TransformKind?) {
        let v = ClipVersion(content: newContent, transformKind: transform)
        // If user navigated back and then applies a transform, truncate forward history.
        if currentVersionIndex < versions.count - 1 {
            versions = Array(versions.prefix(currentVersionIndex + 1))
        }
        versions.append(v)
        currentVersionIndex = versions.count - 1
        updatedAt = Date()
    }

    func navigateVersion(by delta: Int) {
        let target = currentVersionIndex + delta
        guard versions.indices.contains(target) else { return }
        currentVersionIndex = target
        updatedAt = Date()
    }

    private static func detectType(for text: String, imageData: Data?) -> ClipType {
        if imageData != nil { return .image }
        if let url = URL(string: text), url.scheme == "https" || url.scheme == "http" { return .url }
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return .text }
        let keywords = ["func ", "class ", "struct ", "enum ", "import ", "def ", "async ",
                        "function ", "const ", "public ", "private ", "#include", "SELECT "]
        let hits = keywords.filter { text.contains($0) }.count
        let indented = lines.dropFirst().contains { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        return (hits >= 2 || (hits >= 1 && indented)) ? .code : .text
    }
}

// Forward declaration needed by Clip.placements; defined in Workspace.swift
// (SwiftData resolves cross-file @Model references at compile time)
```

- [ ] **Step 4: Run tests — expect pass**

Cmd+U. Expected: all 6 `ClipTests` pass.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/Models/Clip.swift ClipCanvasTests/ClipTests.swift
git commit -m "feat: add Clip model with version history"
```

---

## Task 3: Workspace + CanvasPlacement model

**Files:**
- Create: `ClipCanvas/Models/Workspace.swift`
- Create: `ClipCanvasTests/WorkspaceTests.swift`

Key change from dev: `CanvasPlacement` references a `Clip` by object (not a `Snippet` embedded inside a `WorkspaceCard`). Deleting a placement leaves the clip in history. Deleting a clip cascades to all its placements.

- [ ] **Step 1: Write failing tests**

```swift
// ClipCanvasTests/WorkspaceTests.swift
import Testing
import SwiftData
import Foundation
@testable import ClipCanvas

@Suite struct WorkspaceTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Clip.self, Workspace.self, CanvasPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func addPlacementLinksClip() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let ws = Workspace(name: "Test")
        let clip = Clip(content: "Hello", origin: .clipboard)
        ctx.insert(ws); ctx.insert(clip)
        ws.place(clip: clip, x: 100, y: 200)
        try ctx.save()
        #expect(ws.placements.count == 1)
        #expect(ws.placements.first?.clip?.content == "Hello")
    }

    @Test func removePlacementPreservesClip() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let ws = Workspace(name: "Test")
        let clip = Clip(content: "Hello", origin: .clipboard)
        ctx.insert(ws); ctx.insert(clip)
        let placement = ws.place(clip: clip, x: 0, y: 0)
        try ctx.save()
        ctx.delete(placement)
        try ctx.save()
        // clip still fetchable
        let clips = try ctx.fetch(FetchDescriptor<Clip>())
        #expect(clips.count == 1)
        #expect(ws.placements.isEmpty)
    }

    @Test func nextPositionStaggers() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let ws = Workspace(name: "Test")
        ctx.insert(ws)
        let p1 = ws.nextPosition()
        let clip = Clip(content: "A", origin: .clipboard)
        ctx.insert(clip)
        ws.place(clip: clip, x: p1.x, y: p1.y)
        let p2 = ws.nextPosition()
        #expect(p1.x != p2.x || p1.y != p2.y)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Cmd+U. Expected: compile error — `Workspace`, `CanvasPlacement` not defined.

- [ ] **Step 3: Create Workspace.swift**

```swift
// ClipCanvas/Models/Workspace.swift
import Foundation
import SwiftData

enum CardColor: String, Codable, CaseIterable {
    case `default`, yellow, blue, green, pink, purple
    var label: String { rawValue.capitalized }
}

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

    @Relationship(deleteRule: .cascade, inverse: \AISession.workspace)
    var aiSessions: [AISession] = []

    init(name: String, sortIndex: Int = 0, isActive: Bool = false) {
        self.name = name
        self.sortIndex = sortIndex
        self.isActive = isActive
    }

    @discardableResult
    func place(
        clip: Clip,
        x: Double,
        y: Double,
        width: Double? = nil,
        height: Double? = nil,
        color: CardColor = .default
    ) -> CanvasPlacement {
        let p = CanvasPlacement(
            clip: clip,
            x: x, y: y,
            width: width ?? 240,
            height: height ?? 160,
            color: color
        )
        p.workspace = self
        placements.append(p)
        updatedAt = Date()
        return p
    }

    func nextPosition(offset: Double = 0) -> (x: Double, y: Double) {
        let i = Double(placements.count)
        return (
            x: 180 + offset + i.truncatingRemainder(dividingBy: 5) * 28,
            y: 160 + offset + i.truncatingRemainder(dividingBy: 7) * 22
        )
    }
}

@Model
final class CanvasPlacement {
    var id: UUID = UUID()
    var workspace: Workspace?
    var clip: Clip?      // nullify rule: removing clip from history removes it from canvas too
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var color: CardColor
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(clip: Clip?, x: Double, y: Double, width: Double, height: Double, color: CardColor = .default) {
        self.clip = clip
        self.x = x; self.y = y
        self.width = width; self.height = height
        self.color = color
    }
}

// Forward declaration — AISession defined in AISession.swift
```

- [ ] **Step 4: Run tests — expect pass**

Cmd+U. Expected: all 3 `WorkspaceTests` pass.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/Models/Workspace.swift ClipCanvasTests/WorkspaceTests.swift
git commit -m "feat: add Workspace and CanvasPlacement models"
```

---

## Task 4: AISession + AIMessage model

**Files:**
- Create: `ClipCanvas/Models/AISession.swift`

This replaces both `WorkspaceChatThread` and `TransformRun`. A single session holds messages and optional context clip IDs. The `savedAsClip` flag on `AIMessage` lets the UI show "this response was saved" without duplicating data.

- [ ] **Step 1: Create AISession.swift**

```swift
// ClipCanvas/Models/AISession.swift
import Foundation
import SwiftData

enum MessageRole: String, Codable { case user, assistant }

@Model
final class AISession {
    var id: UUID = UUID()
    var workspace: Workspace?
    var contextClipIDs: [UUID] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \AIMessage.session)
    var messages: [AIMessage] = []

    var visibleMessages: [AIMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    init(workspace: Workspace?, contextClipIDs: [UUID] = []) {
        self.workspace = workspace
        self.contextClipIDs = contextClipIDs
    }
}

@Model
final class AIMessage {
    var id: UUID = UUID()
    var session: AISession?
    var role: MessageRole
    var content: String
    var savedAsClip: Bool = false
    var createdAt: Date = Date()

    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds. (No unit tests needed here — logic lives in AIService.)

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Models/AISession.swift
git commit -m "feat: add AISession and AIMessage models"
```

---

## Task 5: ModelContainer + App entry point

**Files:**
- Modify: `ClipCanvas/ClipCanvasApp.swift`
- Create: `ClipCanvas/App/AppBootstrap.swift`

- [ ] **Step 1: Create AppBootstrap.swift**

```swift
// ClipCanvas/App/AppBootstrap.swift
import SwiftData
import Foundation

enum AppBootstrap {
    static func ensureActiveWorkspace(in context: ModelContext) {
        let descriptor = FetchDescriptor<Workspace>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\Workspace.sortIndex)]
        )
        let activeDescriptor = FetchDescriptor<Workspace>(
            predicate: #Predicate { $0.isActive }
        )
        let active = (try? context.fetch(activeDescriptor)) ?? []
        if !active.isEmpty { return }

        let all = (try? context.fetch(FetchDescriptor<Workspace>(
            sortBy: [SortDescriptor(\Workspace.sortIndex)]
        ))) ?? []

        if let first = all.first {
            first.isActive = true
        } else {
            let ws = Workspace(name: "Canvas 1", sortIndex: 0, isActive: true)
            context.insert(ws)
        }
    }
}
```

- [ ] **Step 2: Rewrite ClipCanvasApp.swift**

```swift
// ClipCanvas/ClipCanvasApp.swift
import SwiftUI
import SwiftData

@main
struct ClipCanvasApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for:
                Clip.self,
                Workspace.self,
                CanvasPlacement.self,
                AISession.self,
                AIMessage.self
            )
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Text("App shell — replace with RootView in Task 10")
                .modelContainer(container)
        }
    }
}
```

- [ ] **Step 3: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add ClipCanvas/ClipCanvasApp.swift ClipCanvas/App/AppBootstrap.swift
git commit -m "feat: configure ModelContainer with all models"
```

---

## Task 6: SensitivityService + ClipboardService

**Files:**
- Create: `ClipCanvas/Services/SensitivityService.swift`
- Create: `ClipCanvas/Services/ClipboardService.swift`
- Create: `ClipCanvasTests/SensitivityServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ClipCanvasTests/SensitivityServiceTests.swift
import Testing
@testable import ClipCanvas

@Suite struct SensitivityServiceTests {

    @Test func normalTextIsNormal() {
        #expect(SensitivityService.detect(for: "Buy milk") == .normal)
    }

    @Test func ssnDetected() {
        #expect(SensitivityService.detect(for: "My SSN: 123-45-6789") == .sensitive)
    }

    @Test func creditCardDetected() {
        #expect(SensitivityService.detect(for: "Card: 4111 1111 1111 1111") == .sensitive)
    }

    @Test func emailDetected() {
        #expect(SensitivityService.detect(for: "reach me at foo@bar.com") == .sensitive)
    }

    @Test func apiKeyDetected() {
        #expect(SensitivityService.detect(for: "api_key=abc123secret") == .privateContent)
    }

    @Test func passwordDetected() {
        #expect(SensitivityService.detect(for: "password: hunter2") == .privateContent)
    }

    @Test func expiryNormalIsNil() {
        let s = SensitivityService.defaultExpiry(for: .normal)
        #expect(s == nil)
    }

    @Test func expirySensitiveIs24h() throws {
        let expiry = try #require(SensitivityService.defaultExpiry(for: .sensitive))
        let diff = expiry.timeIntervalSinceNow
        #expect(diff > 23 * 3600 && diff < 25 * 3600)
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
    private static let sensitivePatterns: [NSRegularExpression] = [
        // SSN
        try! NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#),
        // Credit card (Luhn-format runs of 13-19 digits, with optional spaces/dashes)
        try! NSRegularExpression(pattern: #"\b(?:\d[ -]?){13,19}\b"#),
        // Email
        try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#),
    ]

    private static let privateKeywords = [
        "password", "passwd", "secret", "api_key", "apikey",
        "token", "private_key", "access_key", "auth_key",
    ]

    static func detect(for text: String) -> Sensitivity {
        let lower = text.lowercased()
        if privateKeywords.contains(where: { lower.contains($0) }) { return .privateContent }
        let range = NSRange(text.startIndex..., in: text)
        for pattern in sensitivePatterns {
            if pattern.firstMatch(in: text, range: range) != nil { return .sensitive }
        }
        return .normal
    }

    static func defaultExpiry(for sensitivity: Sensitivity) -> Date? {
        switch sensitivity {
        case .normal:         return nil
        case .sensitive:      return Date(timeIntervalSinceNow: 24 * 3600)
        case .privateContent: return Date(timeIntervalSinceNow: 4 * 3600)
        }
    }
}
```

- [ ] **Step 4: Create ClipboardService.swift**

```swift
// ClipCanvas/Services/ClipboardService.swift
import UIKit

enum ClipboardContent {
    case text(String)
    case image(Data, uti: String)

    var fingerprint: String {
        switch self {
        case .text(let s):       return "t:\(s.hashValue)"
        case .image(let d, _):   return "i:\(d.hashValue)"
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

extension Clip {
    // Factory: create a Clip from clipboard content, running sensitivity detection.
    static func make(from content: ClipboardContent, origin: ClipOrigin) -> Clip {
        switch content {
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let s = trimmed.isEmpty ? text : trimmed
            let sensitivity = SensitivityService.detect(for: s)
            return Clip(
                content: s,
                origin: origin,
                sensitivity: sensitivity,
                expiresAt: SensitivityService.defaultExpiry(for: sensitivity)
            )
        case .image(let data, let uti):
            return Clip(
                content: "",
                imageData: data,
                imageUTI: uti,
                origin: origin
            )
        }
    }
}
```

- [ ] **Step 5: Run tests — expect pass**

Cmd+U. Expected: all 8 `SensitivityServiceTests` pass.

- [ ] **Step 6: Commit**

```bash
git add ClipCanvas/Services/SensitivityService.swift ClipCanvas/Services/ClipboardService.swift ClipCanvasTests/SensitivityServiceTests.swift
git commit -m "feat: add SensitivityService and ClipboardService"
```

---

## Task 7: AIService (unified)

**Files:**
- Create: `ClipCanvas/Services/AIService.swift`
- Create: `ClipCanvasTests/AIServiceTests.swift`

`AIService` wraps both FoundationModels (on-device, for transforms) and OpenAI REST (cloud, for chat and generation). Tests mock the network layer to avoid live API calls.

- [ ] **Step 1: Write tests**

```swift
// ClipCanvasTests/AIServiceTests.swift
import Testing
@testable import ClipCanvas

@Suite struct AIServiceTests {

    @Test func transformPromptDistill() {
        let prompt = AIService.transformPrompt(for: .distill, text: "A B C")
        #expect(prompt.contains("A B C"))
        #expect(prompt.lowercased().contains("distill") || prompt.lowercased().contains("bullet"))
    }

    @Test func transformPromptActionItems() {
        let prompt = AIService.transformPrompt(for: .actionItems, text: "Call John")
        #expect(prompt.contains("Call John"))
        #expect(prompt.lowercased().contains("action") || prompt.lowercased().contains("checklist"))
    }

    @Test func chatRequestBodyContainsPrompt() throws {
        let body = AIService.chatRequestBody(
            prompt: "hello",
            context: "some context",
            history: [],
            model: "gpt-4o-mini"
        )
        let messages = body["messages"] as? [[String: String]] ?? []
        #expect(messages.last?["content"] == "hello")
        #expect(messages.first?["role"] == "system")
    }

    @Test func chatRequestBodyIncludesHistory() throws {
        let history: [(role: String, content: String)] = [("user", "q"), ("assistant", "a")]
        let body = AIService.chatRequestBody(
            prompt: "follow-up",
            context: "",
            history: history,
            model: "gpt-4o-mini"
        )
        let messages = body["messages"] as? [[String: String]] ?? []
        // system + history (2) + new user message = 4
        #expect(messages.count == 4)
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

Cmd+U. Expected: compile error.

- [ ] **Step 3: Create AIService.swift**

```swift
// ClipCanvas/Services/AIService.swift
import Foundation
import FoundationModels

enum AIService {

    // MARK: - Transforms (Apple Intelligence, on-device)

    static func transform(_ kind: TransformKind, clip: Clip) async throws -> String {
        let text = normalise(clip.content)
        if SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(
                instructions: "You transform clipboard text for a focused canvas app. Return only the result, no preamble."
            )
            let response = try await session.respond(to: transformPrompt(for: kind, text: text))
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fallbackTransform(kind, text: text)
    }

    // Internal — exposed for tests
    static func transformPrompt(for kind: TransformKind, text: String) -> String {
        switch kind {
        case .distill:      return "Distill into at most five concise bullets:\n\n\(text)"
        case .actionItems:  return "Extract actionable items as a checklist:\n\n\(text)"
        case .cleanUp:      return "Clean up spacing, grammar, and formatting without changing meaning:\n\n\(text)"
        case .rewrite:      return "Rewrite clearly and concisely:\n\n\(text)"
        case .title:        return "Write a short title, eight words or fewer:\n\n\(text)"
        }
    }

    // MARK: - Chat (OpenAI, cloud)

    static func chat(
        prompt: String,
        context: String,
        history: [(role: String, content: String)],
        apiKey: String
    ) async throws -> String {
        let body = chatRequestBody(prompt: prompt, context: context, history: history, model: "gpt-4o-mini")
        return try await openAIRequest(body: body, apiKey: apiKey)
    }

    // MARK: - Generate (OpenAI, cloud)

    static func generate(prompt: String, apiKey: String) async throws -> String {
        let systemPrompt = "You are an assistant in ClipCanvas, a clipboard manager. The user wants you to create a clip — a focused piece of content they can save and use. Reply with only the requested content, no wrapper text."
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt],
            ],
            "max_tokens": 600,
        ]
        return try await openAIRequest(body: body, apiKey: apiKey)
    }

    // Internal — exposed for tests
    static func chatRequestBody(
        prompt: String,
        context: String,
        history: [(role: String, content: String)],
        model: String
    ) -> [String: Any] {
        let systemContent = context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "You are a helpful assistant in ClipCanvas, a clipboard and notes app. Be concise."
            : "You are a helpful assistant in ClipCanvas. The user has selected these clips as context:\n\n\(context)\n\nAnswer based on this content. Be concise."

        var messages: [[String: String]] = [["role": "system", "content": systemContent]]
        for h in history { messages.append(["role": h.role, "content": h.content]) }
        messages.append(["role": "user", "content": prompt])

        return ["model": model, "messages": messages, "max_tokens": 1000]
    }

    // MARK: - Private

    private static func openAIRequest(body: [String: Any], apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard http.statusCode == 200 else {
            if let err = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data) {
                throw AIError.apiError(err.error.message)
            }
            throw AIError.httpError(http.statusCode)
        }
        let result = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)
        guard let content = result.choices.first?.message.content else { throw AIError.noContent }
        return content
    }

    private static func normalise(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func fallbackTransform(_ kind: TransformKind, text: String) -> String {
        switch kind {
        case .distill:
            return text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                .prefix(5).map { "• \($0)" }.joined(separator: "\n")
        case .actionItems:
            return text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                .prefix(5).map { "- [ ] \($0)" }.joined(separator: "\n")
        case .cleanUp, .rewrite:
            return text.replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .title:
            return text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.prefix(8).joined(separator: " ")
        }
    }
}

enum AIError: LocalizedError {
    case invalidResponse, noContent
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:  return "Invalid response from AI."
        case .noContent:        return "AI returned no content."
        case .httpError(let c): return "HTTP \(c) from AI."
        case .apiError(let m):  return m
        }
    }
}

private struct OpenAIResponseEnvelope: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Msg
        struct Msg: Decodable { let content: String }
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    let error: Detail
    struct Detail: Decodable { let message: String }
}
```

- [ ] **Step 4: Run tests — expect pass**

Cmd+U. Expected: all 4 `AIServiceTests` pass.

- [ ] **Step 5: Commit**

```bash
git add ClipCanvas/Services/AIService.swift ClipCanvasTests/AIServiceTests.swift
git commit -m "feat: add unified AIService (Foundation Models + OpenAI)"
```

---

## Task 8: AppState + navigation skeleton

**Files:**
- Create: `ClipCanvas/App/AppState.swift`
- Create: `ClipCanvas/Views/RootView.swift`

- [ ] **Step 1: Create AppState.swift**

```swift
// ClipCanvas/App/AppState.swift
import Foundation
import Observation
import SwiftData

enum AppRoute: Equatable {
    case workspace(UUID)
    case clips
    case settings
}

@Observable
final class AppState {
    var pendingRoute: AppRoute?
    var showSettings = false
    var showClips = false

    func handle(url: URL) {
        switch url.host {
        case "clips", "library":
            showClips = true
        case "settings":
            showSettings = true
        case "workspace":
            if let id = url.pathComponents.dropFirst().first.flatMap(UUID.init) {
                pendingRoute = .workspace(id)
            }
        default:
            break
        }
    }
}
```

- [ ] **Step 2: Create RootView.swift**

```swift
// ClipCanvas/Views/RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var appState = AppState()

    var body: some View {
        WorkspaceView()
            .environment(appState)
            .sheet(isPresented: $appState.showSettings) { SettingsView() }
            .sheet(isPresented: $appState.showClips) { ClipsView() }
            .task { AppBootstrap.ensureActiveWorkspace(in: context) }
            .onOpenURL { appState.handle(url: $0) }
    }
}
```

- [ ] **Step 3: Update ClipCanvasApp.swift to use RootView**

```swift
// ClipCanvas/ClipCanvasApp.swift
import SwiftUI
import SwiftData

@main
struct ClipCanvasApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for:
                Clip.self, Workspace.self, CanvasPlacement.self,
                AISession.self, AIMessage.self
            )
        } catch {
            fatalError("ModelContainer init failed: \(error)")
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

- [ ] **Step 4: Create stub views so it compiles**

Create minimal stubs (one file each):

```swift
// ClipCanvas/Views/Workspace/WorkspaceView.swift
import SwiftUI
struct WorkspaceView: View {
    var body: some View { Text("Workspace — TODO") }
}
```

```swift
// ClipCanvas/Views/Settings/SettingsView.swift
import SwiftUI
struct SettingsView: View {
    var body: some View { Text("Settings — TODO") }
}
```

```swift
// ClipCanvas/Views/Clips/ClipsView.swift
import SwiftUI
struct ClipsView: View {
    var body: some View { Text("Clips — TODO") }
}
```

- [ ] **Step 5: Build and run in simulator**

Cmd+R. Expected: app launches showing "Workspace — TODO".

- [ ] **Step 6: Commit**

```bash
git add ClipCanvas/App/AppState.swift ClipCanvas/Views/RootView.swift \
  ClipCanvas/ClipCanvasApp.swift ClipCanvas/Views/Workspace/WorkspaceView.swift \
  ClipCanvas/Views/Settings/SettingsView.swift ClipCanvas/Views/Clips/ClipsView.swift
git commit -m "feat: add AppState, RootView, and navigation skeleton"
```

---

## Task 9: DrawRecognitionService

**Files:**
- Create: `ClipCanvas/Services/DrawRecognitionService.swift`

Converts a UIImage (rendered from PencilKit) to text using Vision. This gives drawing a purpose: sketch → text clip.

- [ ] **Step 1: Create DrawRecognitionService.swift**

```swift
// ClipCanvas/Services/DrawRecognitionService.swift
import Vision
import UIKit

enum DrawRecognitionService {
    static func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                guard error == nil else { continuation.resume(returning: nil); return }
                let text = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text?.isEmpty == false ? text : nil)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Services/DrawRecognitionService.swift
git commit -m "feat: add DrawRecognitionService (Vision handwriting recognition)"
```

---

## Task 10: ClipsView (unified clip history)

**Files:**
- Modify: `ClipCanvas/Views/Clips/ClipsView.swift`

Replaces `HistoryView`. Shows ALL clips regardless of which workspace they're on. Filters by type and origin. Key difference: no more "add to canvas" as primary action — placing a clip on a canvas is a secondary action from here.

- [ ] **Step 1: Replace ClipsView.swift stub**

```swift
// ClipCanvas/Views/Clips/ClipsView.swift
import SwiftUI
import SwiftData

struct ClipsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Clip.createdAt, order: .reverse) private var clips: [Clip]
    @Query(filter: #Predicate<Workspace> { $0.isActive }) private var activeWorkspaces: [Workspace]

    @State private var search = ""
    @State private var filterOrigin: ClipOrigin? = nil
    @State private var selectedClip: Clip?
    @State private var feedback: String?

    private var activeWorkspace: Workspace? { activeWorkspaces.first }

    private var filtered: [Clip] {
        clips.filter { clip in
            let matchesSearch = search.isEmpty || clip.content.localizedCaseInsensitiveContains(search)
            let matchesOrigin = filterOrigin == nil || clip.origin == filterOrigin
            return matchesSearch && matchesOrigin
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filtered.isEmpty { filterChips }
                ForEach(filtered) { clip in
                    ClipRow(clip: clip,
                            onCopy: { copy(clip) },
                            onPlace: { placeOnCanvas(clip) })
                    .onTapGesture { selectedClip = clip }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { delete(clip) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { placeOnCanvas(clip) } label: {
                            Label("Canvas", systemImage: "plus.square.on.square")
                        }.tint(.blue)
                        Button { copy(clip) } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }.tint(.green)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Clips")
            .searchable(text: $search, prompt: "Search clips…")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("All") { filterOrigin = nil }
                        Divider()
                        ForEach(ClipOrigin.allCases, id: \.self) { o in
                            Button(o.label) { filterOrigin = o }
                        }
                    } label: {
                        Image(systemName: filterOrigin == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(item: $selectedClip) { clip in
                ClipDetailView(clip: clip)
            }
            .overlay(alignment: .top) {
                if let feedback {
                    FeedbackBanner(message: feedback).padding(.top, 8)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: feedback != nil)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Chip(label: "All", selected: filterOrigin == nil) { filterOrigin = nil }
                ForEach(ClipOrigin.allCases, id: \.self) { o in
                    Chip(label: o.label, selected: filterOrigin == o) { filterOrigin = o }
                }
            }.padding(.horizontal, 4)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    }

    private func copy(_ clip: Clip) {
        ClipboardService.write(clip: clip)
        showFeedback("Copied")
    }

    private func placeOnCanvas(_ clip: Clip) {
        guard let ws = activeWorkspace else { showFeedback("No active workspace"); return }
        let pos = ws.nextPosition()
        ws.place(clip: clip, x: pos.x, y: pos.y)
        showFeedback("Placed on canvas")
        dismiss()
    }

    private func delete(_ clip: Clip) {
        context.delete(clip)
    }

    private func showFeedback(_ msg: String) {
        withAnimation { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { feedback = nil }
        }
    }
}

// MARK: - ClipRow

private struct ClipRow: View {
    let clip: Clip
    let onCopy: () -> Void
    let onPlace: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: clip.type.icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(clip.preview)
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer()
                    if clip.hasVersionHistory {
                        Text("v\(clip.versions.count)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(clip.createdAt, style: .relative)
                    Text("·")
                    Text(clip.origin.label)
                    if clip.isPinned {
                        Image(systemName: "pin.fill").foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Small reusable components

struct Chip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct FeedbackBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

- [ ] **Step 2: Create stub ClipDetailView so it compiles**

```swift
// ClipCanvas/Views/Clips/ClipDetailView.swift
import SwiftUI
struct ClipDetailView: View {
    let clip: Clip
    var body: some View { Text("Clip detail — TODO") }
}
```

- [ ] **Step 3: Build and run**

Cmd+R. Navigate to Clips sheet. Expected: shows list (empty on fresh install, or clips if you've been testing).

- [ ] **Step 4: Commit**

```bash
git add ClipCanvas/Views/Clips/ClipsView.swift ClipCanvas/Views/Clips/ClipDetailView.swift
git commit -m "feat: implement ClipsView with filter, swipe actions, and canvas placement"
```

---

## Task 11: ClipDetailView + version navigation

**Files:**
- Modify: `ClipCanvas/Views/Clips/ClipDetailView.swift`

This is the key UX for version history: swipe or tap arrows to navigate between transform versions. Transform buttons appear here, showing the clip being mutated in place.

- [ ] **Step 1: Replace ClipDetailView stub**

```swift
// ClipCanvas/Views/Clips/ClipDetailView.swift
import SwiftUI
import SwiftData

struct ClipDetailView: View {
    @Bindable var clip: Clip
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isTransforming = false
    @State private var feedback: String?
    @AppStorage("openAIKey") private var openAIKey = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if clip.hasVersionHistory { versionNav }
                contentArea
                Divider()
                transformBar
            }
            .navigationTitle(clip.type.icon.isEmpty ? "Clip" : "Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Copy", systemImage: "doc.on.doc") {
                            ClipboardService.write(clip: clip)
                        }
                        Toggle(isOn: $clip.isPinned) {
                            Label("Pin", systemImage: "pin")
                        }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            context.delete(clip)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(alignment: .top) {
                if let feedback {
                    FeedbackBanner(message: feedback).padding(.top, 8)
                }
            }
        }
    }

    // Version nav strip: ← v2/3 →
    private var versionNav: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.2)) { clip.navigateVersion(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .disabled(clip.currentVersionIndex == 0)

            VStack(spacing: 2) {
                Text("v\(clip.currentVersionIndex + 1) of \(clip.versions.count)")
                    .font(.caption.weight(.medium))
                if let transform = clip.versions[clip.currentVersionIndex].transformKind {
                    Text(transform.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                withAnimation(.spring(duration: 0.2)) { clip.navigateVersion(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .disabled(clip.currentVersionIndex == clip.versions.count - 1)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private var contentArea: some View {
        ScrollView {
            Group {
                if clip.type == .image, let data = clip.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFit()
                        .padding()
                } else {
                    Text(clip.content.isEmpty ? "Empty clip" : clip.content)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // Transform action strip at the bottom
    private var transformBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TransformKind.allCases, id: \.self) { kind in
                    Button {
                        applyTransform(kind)
                    } label: {
                        HStack(spacing: 4) {
                            if isTransforming {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "wand.and.sparkles")
                            }
                            Text(kind.label)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isTransforming || clip.type == .image)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func applyTransform(_ kind: TransformKind) {
        guard !isTransforming else { return }
        isTransforming = true
        Task {
            do {
                let result = try await AIService.transform(kind, clip: clip)
                withAnimation {
                    clip.applyVersion(result, transform: kind)
                }
                showFeedback("\(kind.label) applied")
            } catch {
                showFeedback(error.localizedDescription)
            }
            isTransforming = false
        }
    }

    private func showFeedback(_ msg: String) {
        withAnimation { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { feedback = nil }
        }
    }
}
```

- [ ] **Step 2: Build and test in simulator**

Run the app. Add a clip manually. Open ClipDetailView. Tap a transform — verify the version navigator appears and content updates in place. Navigate ← and → to verify version history.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Clips/ClipDetailView.swift
git commit -m "feat: implement ClipDetailView with in-place transform and version navigation"
```

---

## Task 12: AIPanel (unified chat + generate)

**Files:**
- Create: `ClipCanvas/Views/AI/AIPanel.swift`

This replaces `WorkspaceChatPanel`. Chat with selected clips as context. AI replies can be saved as clips with one tap. There's also a "Generate" mode where the user asks AI to create content from scratch.

- [ ] **Step 1: Create AIPanel.swift**

```swift
// ClipCanvas/Views/AI/AIPanel.swift
import SwiftUI
import SwiftData

struct AIPanel: View {
    let workspace: Workspace
    let contextClips: [Clip]
    let close: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage("openAIKey") private var openAIKey = ""
    @State private var session: AISession?
    @State private var inputText = ""
    @State private var isSending = false
    @State private var isGenerateMode = false  // true = generate new clip, false = chat
    @State private var error: String?

    private var messages: [AIMessage] { session?.visibleMessages ?? [] }

    private var contextText: String {
        contextClips.map(\.content).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if messages.isEmpty && !isSending {
                emptyState
            } else {
                messageList
            }
            Divider()
            inputBar
        }
        .task { ensureSession() }
        .alert("AI Error", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
            VStack(alignment: .leading, spacing: 1) {
                Text(isGenerateMode ? "Generate Clip" : "AI Chat")
                    .font(.headline)
                if !contextClips.isEmpty {
                    Text("\(contextClips.count) clip\(contextClips.count == 1 ? "" : "s") as context")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Generate", isOn: $isGenerateMode.animation())
                .toggleStyle(.button)
                .font(.caption.weight(.medium))
                .tint(.purple)
            Button(action: close) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: isGenerateMode ? "plus.square.dashed" : "bubble.left.and.bubble.right")
                .font(.title2).foregroundStyle(.tertiary)
            Text(isGenerateMode
                 ? "Describe a clip to create — a list, draft, summary, or any content."
                 : "Ask about your clips or paste context here.")
                .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg, onSaveAsClip: { saveAsClip(msg) })
                            .id(msg.id)
                    }
                    if isSending {
                        TypingDots().id("typing")
                    }
                }
                .padding(12)
                .animation(.easeInOut(duration: 0.2), value: isSending)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id ?? "typing", anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                isGenerateMode ? "Describe the clip to create…" : "Ask, compare, summarise…",
                text: $inputText, axis: .vertical
            )
            .lineLimit(1...4)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .disabled(isSending)

            Button(action: send) {
                ZStack {
                    Circle()
                        .fill(canSend ? (isGenerateMode ? Color.purple : Color.accentColor) : Color.secondary.opacity(0.2))
                        .frame(width: 34, height: 34)
                    if isSending {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: isGenerateMode ? "plus" : "arrow.up")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    }
                }
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: isSending)
        }
        .padding(12)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && !openAIKey.isEmpty
    }

    private func ensureSession() {
        guard session == nil else { return }
        let s = AISession(workspace: workspace, contextClipIDs: contextClips.map(\.id))
        context.insert(s)
        workspace.aiSessions.append(s)
        session = s
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        ensureSession()
        guard let session else { return }

        inputText = ""
        isSending = true

        let userMsg = AIMessage(role: .user, content: text)
        userMsg.session = session
        session.messages.append(userMsg)
        context.insert(userMsg)

        let history = messages.dropLast().map { (role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        Task {
            do {
                let reply: String
                if isGenerateMode {
                    reply = try await AIService.generate(prompt: text, apiKey: openAIKey)
                } else {
                    reply = try await AIService.chat(
                        prompt: text, context: contextText, history: history, apiKey: openAIKey
                    )
                }
                let assistantMsg = AIMessage(role: .assistant, content: reply)
                assistantMsg.session = session
                session.messages.append(assistantMsg)
                session.updatedAt = Date()
                context.insert(assistantMsg)
            } catch {
                self.error = error.localizedDescription
            }
            isSending = false
        }
    }

    private func saveAsClip(_ message: AIMessage) {
        guard !message.savedAsClip else { return }
        let clip = Clip(content: message.content, origin: .aiGenerated)
        context.insert(clip)
        let pos = workspace.nextPosition(offset: 40)
        workspace.place(clip: clip, x: pos.x, y: pos.y)
        message.savedAsClip = true
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: AIMessage
    let onSaveAsClip: () -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(
                        isUser ? Color.accentColor : Color.secondary.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .foregroundStyle(isUser ? .white : .primary)

                if !isUser {
                    Button {
                        onSaveAsClip()
                    } label: {
                        Label(
                            message.savedAsClip ? "Saved as clip" : "Save as clip",
                            systemImage: message.savedAsClip ? "checkmark.circle.fill" : "plus.square"
                        )
                        .font(.caption)
                        .foregroundStyle(message.savedAsClip ? .secondary : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - TypingDots

private struct TypingDots: View {
    @State private var animate = false
    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .offset(y: animate ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.13),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .onAppear { animate = true }
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/AI/AIPanel.swift
git commit -m "feat: implement unified AIPanel with chat, generate, and save-as-clip"
```

---

## Task 13: CanvasCard

**Files:**
- Create: `ClipCanvas/Views/Workspace/CanvasCard.swift`

Shows the current clip version. Version badge + arrows visible when the clip has history. Long-press context menu has Transform options that call `clip.applyVersion` directly.

- [ ] **Step 1: Create CanvasCard.swift**

```swift
// ClipCanvas/Views/Workspace/CanvasCard.swift
import SwiftUI

struct CanvasCard: View {
    @Bindable var placement: CanvasPlacement
    let isSelected: Bool
    let isTransforming: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void   // opens ClipDetailView
    let onDelete: () -> Void
    let onTransform: (TransformKind) -> Void
    let onAskAI: () -> Void

    var clip: Clip? { placement.clip }

    var body: some View {
        ZStack(alignment: .bottom) {
            cardBackground
                .overlay(cardContent)
                .overlay(selectionRing)

            if let clip, clip.hasVersionHistory {
                versionNav(clip: clip)
                    .padding(.bottom, 6)
            }
        }
        .frame(width: placement.width, height: placement.height)
        .position(x: placement.x, y: placement.y)
        .contextMenu { contextMenuItems }
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onTap() }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(cardFill)
            .shadow(color: .black.opacity(isSelected ? 0.22 : 0.09), radius: isSelected ? 14 : 6, y: 3)
    }

    private var cardFill: some ShapeStyle {
        switch placement.color {
        case .default: return AnyShapeStyle(.regularMaterial)
        case .yellow:  return AnyShapeStyle(Color.yellow.opacity(0.85))
        case .blue:    return AnyShapeStyle(Color.blue.opacity(0.2))
        case .green:   return AnyShapeStyle(Color.green.opacity(0.2))
        case .pink:    return AnyShapeStyle(Color.pink.opacity(0.2))
        case .purple:  return AnyShapeStyle(Color.purple.opacity(0.2))
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if isTransforming {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let clip {
            VStack(alignment: .leading, spacing: 4) {
                if clip.type == .image, let data = clip.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                } else {
                    Text(clip.preview)
                        .font(.system(size: 13))
                        .lineLimit(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var selectionRing: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.accentColor, lineWidth: isSelected ? 2.5 : 0)
    }

    private func versionNav(clip: Clip) -> some View {
        HStack(spacing: 6) {
            Button { withAnimation { clip.navigateVersion(by: -1) } } label: {
                Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
            }
            .disabled(clip.currentVersionIndex == 0)

            Text("v\(clip.currentVersionIndex + 1)/\(clip.versions.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Button { withAnimation { clip.navigateVersion(by: 1) } } label: {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .disabled(clip.currentVersionIndex == clip.versions.count - 1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Ask AI", systemImage: "sparkles") { onAskAI() }
        Menu("Transform", systemImage: "wand.and.sparkles") {
            ForEach(TransformKind.allCases, id: \.self) { kind in
                Button(kind.label) { onTransform(kind) }
            }
        }
        Divider()
        Button("Copy", systemImage: "doc.on.doc") {
            if let clip { ClipboardService.write(clip: clip) }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Workspace/CanvasCard.swift
git commit -m "feat: add CanvasCard with version nav and transform context menu"
```

---

## Task 14: CanvasSurface

**Files:**
- Create: `ClipCanvas/Views/Workspace/CanvasSurface.swift`

Infinite scrollable canvas with zoom. Cards are positioned absolutely. Drag to move. Tap to select.

- [ ] **Step 1: Create CanvasSurface.swift**

```swift
// ClipCanvas/Views/Workspace/CanvasSurface.swift
import SwiftUI
import SwiftData

struct CanvasSurface: View {
    let workspace: Workspace?
    @Binding var selectedIDs: Set<UUID>
    let runningTransforms: Set<UUID>
    let openAI: (Clip) -> Void
    let onTransform: (CanvasPlacement, TransformKind) -> Void
    let onDeletePlacement: (CanvasPlacement) -> Void
    let onDoubleTapPlacement: (CanvasPlacement) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvasBackground(in: geo)

                let placements = workspace?.placements ?? []
                ForEach(placements) { placement in
                    if let clip = placement.clip {
                        draggableCard(placement: placement, clip: clip)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { selectedIDs.removeAll() }
        }
        .clipped()
        .simultaneousGesture(
            MagnificationGesture()
                .updating($gestureScale) { value, state, _ in state = value }
                .onEnded { scale = (scale * $0).clamped(to: 0.25...4.0) }
        )
    }

    private func canvasBackground(in geo: GeometryProxy) -> some View {
        Color.clear
            .background(
                Canvas { ctx, size in
                    let spacing: CGFloat = 28 * scale
                    let startX = offset.width.truncatingRemainder(dividingBy: spacing)
                    let startY = offset.height.truncatingRemainder(dividingBy: spacing)
                    var x = startX; while x < size.width { x += spacing
                        var y = startY; while y < size.height { y += spacing
                            ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(.secondary.opacity(0.18)))
                        }
                    }
                }
            )
    }

    private func draggableCard(placement: CanvasPlacement, clip: Clip) -> some View {
        let isSelected = selectedIDs.contains(placement.id)
        let transforming = runningTransforms.contains(placement.id)

        return CanvasCard(
            placement: placement,
            isSelected: isSelected,
            isTransforming: transforming,
            onTap: {
                if isSelected { selectedIDs.remove(placement.id) }
                else { selectedIDs.insert(placement.id) }
            },
            onDoubleTap: { onDoubleTapPlacement(placement) },
            onDelete: { onDeletePlacement(placement) },
            onTransform: { kind in onTransform(placement, kind) },
            onAskAI: { openAI(clip) }
        )
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    placement.x += value.translation.width / scale
                    placement.y += value.translation.height / scale
                }
                .onEnded { _ in placement.updatedAt = Date() }
        )
        .scaleEffect(scale * gestureScale)
        .offset(offset)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Workspace/CanvasSurface.swift
git commit -m "feat: add CanvasSurface with infinite canvas, zoom, and drag"
```

---

## Task 15: WorkspaceView (full implementation)

**Files:**
- Modify: `ClipCanvas/Views/Workspace/WorkspaceView.swift`

Replaces the stub with full workspace logic: clipboard monitoring, paste, transform execution (mutates clip in place), AI panel.

- [ ] **Step 1: Replace WorkspaceView.swift**

```swift
// ClipCanvas/Views/Workspace/WorkspaceView.swift
import SwiftUI
import SwiftData

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Workspace> { !($0.name == "") },
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]

    @State private var selectedIDs = Set<UUID>()
    @State private var runningTransforms = Set<UUID>()
    @State private var showAIPanel = false
    @State private var aiContextClips: [Clip] = []
    @State private var detailPlacement: CanvasPlacement?
    @State private var feedback: String?
    @State private var lastClipboardFingerprint: String?
    @State private var showDrawCapture = false

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var selectedPlacements: [CanvasPlacement] {
        activeWorkspace?.placements.filter { selectedIDs.contains($0.id) } ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasSurface(
                    workspace: activeWorkspace,
                    selectedIDs: $selectedIDs,
                    runningTransforms: runningTransforms,
                    openAI: { clip in aiContextClips = [clip]; showAIPanel = true },
                    onTransform: runTransform,
                    onDeletePlacement: deletePlacement,
                    onDoubleTapPlacement: { detailPlacement = $0 }
                )

                VStack {
                    topBar
                    Spacer()
                    if !selectedIDs.isEmpty { selectionBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
                    if let feedback {
                        FeedbackBanner(message: feedback)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.22), value: selectedIDs.isEmpty)
                .animation(.easeInOut(duration: 0.2), value: feedback != nil)

                if showAIPanel, let workspace = activeWorkspace {
                    VStack {
                        Spacer()
                        AIPanel(
                            workspace: workspace,
                            contextClips: aiContextClips,
                            close: { showAIPanel = false }
                        )
                        .frame(maxHeight: 380)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(radius: 20)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(duration: 0.3), value: showAIPanel)
                }
            }
        }
        .sheet(item: $detailPlacement) { placement in
            if let clip = placement.clip {
                ClipDetailView(clip: clip)
            }
        }
        .sheet(isPresented: $showDrawCapture) {
            DrawCaptureView { clip in
                guard let ws = activeWorkspace else { return }
                context.insert(clip)
                let pos = ws.nextPosition()
                ws.place(clip: clip, x: pos.x, y: pos.y)
                showFeedback("Drawing saved as clip")
            }
        }
        .task(id: activeWorkspace?.id) {
            await monitorClipboard()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Menu {
                ForEach(workspaces) { ws in
                    Button {
                        activateWorkspace(ws)
                    } label: {
                        Label(ws.name, systemImage: ws.isActive ? "checkmark" : "rectangle.3.group")
                    }
                }
                Divider()
                Button("New Workspace", systemImage: "plus") { createWorkspace() }
            } label: {
                HStack(spacing: 4) {
                    Text(activeWorkspace?.name ?? "Workspace")
                        .font(.headline)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Button { showDrawCapture = true } label: {
                    Image(systemName: "pencil.tip.crop.circle")
                }
                Button {
                    aiContextClips = selectedPlacements.compactMap(\.clip)
                    showAIPanel.toggle()
                } label: {
                    Image(systemName: "sparkles")
                }
                Button { appState.showClips = true } label: {
                    Image(systemName: "clock")
                }
                Button { appState.showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                Button { pasteFromClipboard() } label: {
                    Image(systemName: "doc.on.clipboard")
                }
            }
            .font(.system(size: 16))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        HStack(spacing: 4) {
            Text("\(selectedIDs.count) selected")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)

            Divider().frame(height: 20)

            Button { aiContextClips = selectedPlacements.compactMap(\.clip); showAIPanel = true } label: {
                Image(systemName: "sparkles")
            }

            Menu {
                ForEach(TransformKind.allCases, id: \.self) { kind in
                    Button(kind.label) { transformSelected(kind) }
                }
            } label: {
                Image(systemName: "wand.and.sparkles")
            }

            Button { copySelected() } label: {
                Image(systemName: "doc.on.doc")
            }

            Divider().frame(height: 20)

            Button(role: .destructive) { deleteSelected() } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 15))
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(radius: 8, y: 2)
        .padding(.bottom, 12)
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        guard let content = ClipboardService.readContent() else { showFeedback("Clipboard is empty"); return }
        guard let ws = activeWorkspace else { return }
        let clip = Clip.make(from: content, origin: .clipboard)
        context.insert(clip)
        let pos = ws.nextPosition()
        let placement = ws.place(clip: clip, x: pos.x, y: pos.y)
        selectedIDs = [placement.id]
        lastClipboardFingerprint = content.fingerprint
        showFeedback("Pasted")
    }

    private func monitorClipboard() async {
        lastClipboardFingerprint = ClipboardService.readContent()?.fingerprint
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard let content = ClipboardService.readContent() else { continue }
            guard content.fingerprint != lastClipboardFingerprint else { continue }
            lastClipboardFingerprint = content.fingerprint
            guard let ws = activeWorkspace else { continue }
            let clip = Clip.make(from: content, origin: .clipboard)
            context.insert(clip)
            let pos = ws.nextPosition()
            ws.place(clip: clip, x: pos.x, y: pos.y)
            showFeedback("Captured from clipboard")
        }
    }

    private func runTransform(_ placement: CanvasPlacement, kind: TransformKind) {
        guard let clip = placement.clip, clip.type != .image else { return }
        runningTransforms.insert(placement.id)
        Task {
            do {
                let result = try await AIService.transform(kind, clip: clip)
                withAnimation { clip.applyVersion(result, transform: kind) }
                showFeedback("\(kind.label) applied")
            } catch {
                showFeedback(error.localizedDescription)
            }
            runningTransforms.remove(placement.id)
        }
    }

    private func transformSelected(_ kind: TransformKind) {
        for placement in selectedPlacements { runTransform(placement, kind: kind) }
    }

    private func deletePlacement(_ placement: CanvasPlacement) {
        selectedIDs.remove(placement.id)
        context.delete(placement)
        activeWorkspace?.updatedAt = Date()
    }

    private func deleteSelected() {
        for p in selectedPlacements { context.delete(p) }
        selectedIDs.removeAll()
        activeWorkspace?.updatedAt = Date()
    }

    private func copySelected() {
        let text = selectedPlacements.compactMap(\.clip?.content).joined(separator: "\n\n")
        guard !text.isEmpty else { return }
        ClipboardService.writeString(text)
        lastClipboardFingerprint = ClipboardContent.text(text).fingerprint
        showFeedback("Copied \(selectedIDs.count) clip\(selectedIDs.count == 1 ? "" : "s")")
    }

    private func activateWorkspace(_ workspace: Workspace) {
        for ws in workspaces { ws.isActive = ws.id == workspace.id }
        selectedIDs.removeAll()
    }

    private func createWorkspace() {
        for ws in workspaces where ws.isActive { ws.isActive = false }
        let newWs = Workspace(
            name: "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        )
        context.insert(newWs)
        selectedIDs.removeAll()
    }

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

Cmd+R. Expected: app shows infinite canvas. Paste from clipboard. Cards appear. Context menu should show Transform options. AI panel should slide up from bottom.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Workspace/WorkspaceView.swift
git commit -m "feat: implement full WorkspaceView with clipboard monitoring, transforms, AI panel"
```

---

## Task 16: DrawCaptureView

**Files:**
- Create: `ClipCanvas/Views/Draw/DrawCaptureView.swift`

**Why draw?** Three answers: (1) Sketch → recognized as text clip. (2) Sketch → saved as image clip. (3) Sketch → AI interprets it. This gives PencilKit a clear purpose beyond annotation.

- [ ] **Step 1: Create DrawCaptureView.swift**

```swift
// ClipCanvas/Views/Draw/DrawCaptureView.swift
import SwiftUI
import PencilKit

struct DrawCaptureView: View {
    let onSave: (Clip) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()
    @State private var isRecognizing = false
    @State private var recognizedText: String?
    @State private var showRecognizedPreview = false
    @AppStorage("openAIKey") private var openAIKey = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DrawingCanvas(drawing: $drawing)
                    .ignoresSafeArea(edges: .bottom)

                VStack {
                    Spacer()
                    actionBar
                }

                if isRecognizing {
                    ProgressView("Recognizing…")
                        .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Sketch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") { drawing = PKDrawing() }
                        .disabled(drawing.strokes.isEmpty)
                }
            }
            .sheet(isPresented: $showRecognizedPreview) {
                if let text = recognizedText {
                    RecognizedTextSheet(text: text) { accepted in
                        let clip = Clip(content: accepted, origin: .drawn)
                        onSave(clip)
                        dismiss()
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            // Recognize handwriting → text clip
            Button {
                recognizeText()
            } label: {
                Label("Recognize Text", systemImage: "text.viewfinder")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(drawing.strokes.isEmpty || isRecognizing)

            // Save as image clip
            Button {
                saveAsImage()
            } label: {
                Label("Save as Image", systemImage: "photo")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(drawing.strokes.isEmpty)
        }
        .padding(.bottom, 20)
    }

    private func recognizeText() {
        guard !drawing.strokes.isEmpty else { return }
        isRecognizing = true
        Task {
            // Render drawing to UIImage for Vision
            let renderer = UIGraphicsImageRenderer(bounds: drawing.bounds)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(drawing.bounds)
                drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
                    .draw(in: drawing.bounds)
            }
            if let text = await DrawRecognitionService.recognizeText(in: image), !text.isEmpty {
                recognizedText = text
                showRecognizedPreview = true
            } else {
                recognizedText = nil
                // If recognition fails, fall back to saving as image
                saveAsImage()
            }
            isRecognizing = false
        }
    }

    private func saveAsImage() {
        let bounds = drawing.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 400, height: 300)
            : drawing.bounds.insetBy(dx: -20, dy: -20)
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(bounds)
            drawing.image(from: bounds, scale: UIScreen.main.scale).draw(in: bounds)
        }
        if let data = image.pngData() {
            let clip = Clip(content: "", imageData: data, imageUTI: "public.png", origin: .drawn)
            onSave(clip)
            dismiss()
        }
    }
}

// MARK: - PKCanvasView wrapper

private struct DrawingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing { canvas.drawing = drawing }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: DrawingCanvas
        init(_ parent: DrawingCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            parent.drawing = canvas.drawing
        }
    }
}

// MARK: - Recognized text preview

private struct RecognizedTextSheet: View {
    @State var text: String
    let onAccept: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Recognized Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save as Clip") {
                            onAccept(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}
```

- [ ] **Step 2: Build and run**

Cmd+R. Tap the pencil icon in the top bar. DrawCaptureView should appear. Draw something. Tap "Recognize Text" — Vision processes it and shows the recognized text for editing. "Save as Image" saves the drawing as an image clip.

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Draw/DrawCaptureView.swift
git commit -m "feat: add DrawCaptureView — sketch to text clip (Vision) or image clip"
```

---

## Task 17: SettingsView

**Files:**
- Modify: `ClipCanvas/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Replace SettingsView stub**

```swift
// ClipCanvas/Views/Settings/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("openAIKey") private var openAIKey = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI") {
                    LabeledContent("OpenAI API Key") {
                        SecureField("sk-…", text: $openAIKey)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Text("Used for Chat and Generate. Transforms use Apple Intelligence (on-device, free).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button("Delete All Clips & Workspaces", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete everything?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) { deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All clips, workspaces, and AI sessions will be permanently removed.")
            }
        }
    }

    private func deleteAll() {
        try? context.delete(model: Clip.self)
        try? context.delete(model: Workspace.self)
        try? context.delete(model: AISession.self)
        AppBootstrap.ensureActiveWorkspace(in: context)
    }
}

private extension Bundle {
    var appVersion: String {
        "\(infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
    }
}
```

- [ ] **Step 2: Build and run**

Cmd+R. Open Settings from top bar. Enter an OpenAI key. Verify it persists across launches (AppStorage).

- [ ] **Step 3: Commit**

```bash
git add ClipCanvas/Views/Settings/SettingsView.swift
git commit -m "feat: implement SettingsView with OpenAI key and data management"
```

---

## Post-build checklist

After all tasks pass, verify the full user flows:

- [ ] **Clipboard capture**: Copy text in another app. Open ClipCanvas. Card appears on canvas automatically.
- [ ] **Transform in place**: Tap a card → context menu → Transform → Distill. Card content updates. Version badge `v2` appears. Tap version arrows to navigate back.
- [ ] **AI chat**: Select a card → top bar sparkles icon → type a question → AI responds. Tap "Save as clip" on a reply → new card placed on canvas.
- [ ] **AI generate**: In AI panel, toggle Generate mode → type "Create a shopping list for a dinner party" → result appears → save as clip.
- [ ] **Draw to clip**: Tap pencil icon → draw text → Recognize Text → review recognized text → Save as Clip → clip appears on canvas.
- [ ] **Clips list**: Tap clock icon → all clips shown → filter by AI → only AI-generated clips shown → tap a clip → ClipDetailView opens → transforms work.
- [ ] **Version navigation**: Tap a transformed clip in ClipDetail → version nav strip shows → swipe between versions.
- [ ] **Multiple workspaces**: Create a second workspace → place a clip from history → same Clip object appears on both canvases.

---

## Self-review

**Spec coverage:**
- ✅ AI chat + AI transforms unified → `AIService` + `AIPanel` (replaces separate `OpenAIService`, `TransformService`, `WorkspaceChatPanel`)
- ✅ Transforms mutate original clip → `clip.applyVersion()`, no new card created
- ✅ AI can create clips → Generate mode in `AIPanel`, "Save as clip" on chat replies
- ✅ History and workspace clips share the same `Clip` object → `CanvasPlacement` is a pointer, not a copy
- ✅ Draw mode has clear purpose → DrawCaptureView: sketch → text (Vision) / image / placeholder for AI interpretation
- ✅ Version navigation on canvas card → `CanvasCard` version nav strip
- ✅ Sensitivity detection + expiry → `SensitivityService`

**Placeholder scan:** None found — all steps include real code.

**Type consistency check:**
- `Clip.applyVersion(_:transform:)` — used in `ClipDetailView` ✅, `WorkspaceView.runTransform` ✅, `CanvasCard.contextMenuItems` (via `onTransform` closure) ✅
- `Workspace.place(clip:x:y:)` → returns `CanvasPlacement` — used in `WorkspaceView` ✅, `ClipsView` ✅, `AIPanel.saveAsClip` ✅
- `ClipboardService.write(clip:)` — used in `ClipsView` ✅, `ClipDetailView` ✅, `CanvasCard` ✅
- `AIService.transform(_:clip:)` — used in `WorkspaceView.runTransform` ✅, `ClipDetailView.applyTransform` ✅
- `Clip.make(from:origin:)` — factory defined in `ClipboardService.swift`, used in `WorkspaceView` ✅
- `FeedbackBanner` defined in `ClipsView.swift` — used in `ClipsView` ✅ and `ClipDetailView` ✅. **Note:** move `FeedbackBanner` and `Chip` to a shared file if both compile in the same module (they will — SwiftUI views in the same target are visible to each other without import).
