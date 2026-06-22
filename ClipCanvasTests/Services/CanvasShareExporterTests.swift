import CoreGraphics
import Foundation
import Testing
@testable import ClipCanvas

@MainActor @Suite struct CanvasShareExporterTests {
    @Test func workspaceShareIncludesNameAndCardText() {
        let workspace = Workspace(name: "Research")
        _ = workspace.createNote(
            centeredAt: .zero,
            size: CGSize(width: 120, height: 80),
            text: "First card"
        )

        let text = CanvasShareExporter.workspaceText(workspace)

        #expect(text.contains("# Research"))
        #expect(text.contains("First card"))
    }

    @Test func cardShareOrdersByZIndex() throws {
        let workspace = Workspace(name: "Canvas")
        let later = workspace.createNote(centeredAt: .zero, size: CGSize(width: 120, height: 80), text: "Later")
        let first = workspace.createNote(centeredAt: .zero, size: CGSize(width: 120, height: 80), text: "First")
        later.zIndex = 2
        first.zIndex = 1

        let text = CanvasShareExporter.cardsText([later, first])
        let firstRange = try #require(text.range(of: "First"))
        let laterRange = try #require(text.range(of: "Later"))

        #expect(firstRange.lowerBound < laterRange.lowerBound)
    }

    @Test func imageShareWritesTemporaryFile() throws {
        let workspace = Workspace(name: "Canvas")
        let clip = Clip(content: "Image", imageData: Data([1, 2, 3]), imageUTI: "public.png", origin: .typed)
        let object = workspace.place(clip: clip)

        let urls = CanvasShareExporter.imageURLs(for: [object])

        let url = try #require(urls.first)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
