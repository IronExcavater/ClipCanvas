import Testing
import Foundation
import SwiftData
@testable import ClipCanvas

@Suite struct ClipModelTests {

    // MARK: - Defaults

    @Test func defaultColorIsCloud() {
        let clip = Clip(content: "hello", origin: .clipboard)
        #expect(clip.color == .cloud)
    }

    @Test func notDeletedByDefault() {
        let clip = Clip(content: "hello", origin: .clipboard)
        #expect(clip.deletedAt == nil)
    }

    // MARK: - Soft delete

    @Test func softDeleteSetsDeletedAt() {
        let clip = Clip(content: "hello", origin: .clipboard)
        clip.softDelete()
        #expect(clip.deletedAt != nil)
        #expect(!clip.isPinned)
    }

    @Test func restoreClearsDeletedAt() {
        let clip = Clip(content: "hello", origin: .clipboard)
        clip.softDelete()
        clip.restore()
        #expect(clip.deletedAt == nil)
    }

    // MARK: - URL detection

    @Test func httpsUrlDetected() {
        #expect(Clip(content: "https://apple.com", origin: .clipboard).type == .url)
    }

    @Test func httpUrlDetected() {
        #expect(Clip(content: "http://example.com/path?q=1", origin: .clipboard).type == .url)
    }

    @Test func wwwUrlDetected() {
        #expect(Clip(content: "www.google.com", origin: .clipboard).type == .url)
    }

    @Test func plainTextNotUrl() {
        #expect(Clip(content: "Buy oat milk", origin: .clipboard).type == .text)
    }

    @Test func multilineTextNotUrl() {
        #expect(Clip(content: "https://apple.com\nhttps://google.com", origin: .clipboard).type != .url)
    }

    // MARK: - Code detection

    @Test func swiftFunctionDetected() {
        let code = "func foo() {\n    return 42\n}"
        #expect(Clip(content: code, origin: .clipboard).type == .code)
    }

    @Test func pythonFunctionDetected() {
        let code = "def calculate(x):\n    return x * 2\n\nresult = calculate(5)"
        #expect(Clip(content: code, origin: .clipboard).type == .code)
    }

    @Test func sqlDetected() {
        let sql = "SELECT id, name\nFROM users\nWHERE active = 1"
        #expect(Clip(content: sql, origin: .clipboard).type == .code)
    }

    @Test func plainTextNotCode() {
        #expect(Clip(content: "Buy oat milk", origin: .clipboard).type == .text)
    }

    @Test func singleLineNotCode() {
        #expect(Clip(content: "let x = 5", origin: .clipboard).type == .text)
    }

    // MARK: - Image type

    @Test func imageTypeWhenDataPresent() {
        let clip = Clip(content: "", imageData: Data([0x89, 0x50]), imageUTI: "public.png", origin: .clipboard)
        #expect(clip.type == .image)
    }

    // MARK: - Preview

    @Test func previewMasksPrivateContent() {
        let clip = Clip(content: "hunter2", origin: .clipboard, sensitivity: .privateContent)
        #expect(clip.preview.allSatisfy { $0 == "•" })
    }

    @Test func previewShowsTextForNormalContent() {
        let clip = Clip(content: "Hello world", origin: .clipboard)
        #expect(clip.preview == "Hello world")
    }

    // MARK: - Deduplication

    @Test func findOrMakeReusesExistingTextClip() throws {
        let container = try ModelContainer(
            for: Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let existing = Clip(content: "Hello world", origin: .clipboard)
        context.insert(existing)

        let result = Clip.findOrMake(from: .text("  Hello world  "), origin: .clipboard, in: context)

        #expect(!result.isNew)
        #expect(result.clip.id == existing.id)
    }

    @Test func bootstrapSeedsBuiltInTagsOnce() throws {
        let container = try ModelContainer(
            for: Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        AppBootstrap.ensureActiveWorkspace(in: context)
        AppBootstrap.ensureActiveWorkspace(in: context)

        let tags = try context.fetch(FetchDescriptor<ClipTag>())
        #expect(tags.count == ClipTag.builtInDefinitions.count)
    }
}
