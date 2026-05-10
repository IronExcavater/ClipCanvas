import Foundation
import UIKit
import UniformTypeIdentifiers

enum PasteboardContent {
    case text(String)
    case image(Data, uti: String)

    // Used only to avoid re-importing the same clipboard payload every polling tick.
    var fingerprint: String {
        switch self {
        case .text(let text):
            "text:\(text)"
        case .image(let data, let uti):
            "image:\(uti):\(data.count):\(Data(data.prefix(48)).base64EncodedString())"
        }
    }
}

struct PasteboardService {
    static func readContent() -> PasteboardContent? {
        if UIPasteboard.general.hasImages,
           let image = UIPasteboard.general.image,
           let data = image.pngData() {
            return .image(data, uti: UTType.png.identifier)
        }

        return UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            .map(PasteboardContent.text)
    }

    static func writeSnippet(_ snippet: Snippet) {
        if let data = snippet.imageData {
            writeImageData(data)
        } else {
            writeString(snippet.text)
        }
    }

    static func writeString(_ text: String) {
        UIPasteboard.general.string = text
    }

    private static func writeImageData(_ data: Data) {
        if let image = UIImage(data: data) {
            UIPasteboard.general.image = image
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
