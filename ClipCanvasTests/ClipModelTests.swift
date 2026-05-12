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
