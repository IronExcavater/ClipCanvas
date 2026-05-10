import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SnippetDragPayload: Transferable {
    let text: String
    let imageData: Data?

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.text)
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
    func snippetDraggable(_ snippet: Snippet?) -> some View {
        draggable(snippet?.dragPayload ?? SnippetDragPayload(text: "", imageData: nil))
    }
}

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
                .textSelection(.enabled)
        }
    }
}

private struct PlatformImage: View {
    let data: Data

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
        } else {
            unavailableImage
        }
    }

    private var unavailableImage: some View {
        ZStack {
            Color.clipCanvasSecondaryBackground
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
