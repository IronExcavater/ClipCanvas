import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Transferable is the protocol that powers drag-and-drop and copy-paste in SwiftUI.
// A type that conforms to Transferable declares how to export its data in various formats.
struct SnippetDragPayload: Transferable {
    let text: String
    let imageData: Data?

    static var transferRepresentation: some TransferRepresentation {
        // ProxyRepresentation exports the text field as a plain string — other apps
        // (Notes, Messages, etc.) can accept drops of this format.
        ProxyRepresentation(exporting: \.text)
        // DataRepresentation exports raw PNG bytes for image snippets.
        DataRepresentation(exportedContentType: .png) { payload in
            guard let imageData = payload.imageData else {
                throw SnippetDragError.noImageData
            }
            return imageData
        }
    }
}

private enum SnippetDragError: Error {
    case noImageData
}

extension Snippet {
    var dragPayload: SnippetDragPayload {
        SnippetDragPayload(text: dragText, imageData: imageData)
    }
}

extension View {
    // Convenience modifier — wraps SwiftUI's `.draggable()` so call sites don't need
    // to build the payload themselves. Works on any view that displays a Snippet.
    func snippetDraggable(_ snippet: Snippet?) -> some View {
        draggable(snippet?.dragPayload ?? SnippetDragPayload(text: "", imageData: nil))
    }
}

// Renders the content of a Snippet — used on canvas cards, sidebar rows, and the library.
struct SnippetPreviewContent: View {
    let snippet: Snippet?
    let lineLimit: Int
    let imageHeight: CGFloat

    var body: some View {
        if let snippet, snippet.type == .image, let data = snippet.imageData {
            PlatformImage(data: data)
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: imageHeight, maxHeight: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(alignment: .bottomLeading) {
                    Label("Image", systemImage: "photo")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                        .padding(8)
                }
        } else {
            Text(snippet?.preview ?? "Empty card")
                .font(snippet?.type == .code ? .system(.callout, design: .monospaced) : .body)
                .foregroundStyle((snippet?.text.isEmpty ?? true) ? .secondary : .primary)
                .lineLimit(lineLimit)
                .textSelection(.enabled)    // long-press to select and copy text
        }
    }
}

private struct PlatformImage: View {
    let data: Data

    var body: some View {
        // UIImage(data:) decodes raw image bytes into a UIKit image that SwiftUI can display.
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
        } else {
            ZStack {
                Color.clipCanvasSecondaryBackground
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
