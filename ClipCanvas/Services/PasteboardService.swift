import Foundation
import UIKit
import UniformTypeIdentifiers

// PasteboardContent wraps the two possible clipboard payload types so the rest of the
// app doesn't need to import UIKit or reference UIPasteboard directly.
enum PasteboardContent {
    case text(String)
    case image(Data, uti: String)

    // A compact string that uniquely identifies this payload. The clipboard watcher
    // compares fingerprints instead of full content to avoid re-importing the same item.
    var fingerprint: String {
        switch self {
        case .text(let text):
            "text:\(text)"
        case .image(let data, let uti):
            // Hash the UTI, byte count, and first 48 bytes — fast enough for 60Hz polling.
            "image:\(uti):\(data.count):\(Data(data.prefix(48)).base64EncodedString())"
        }
    }
}

struct PasteboardService {
    // UIPasteboard.general is the system-wide shared clipboard — the same one used by
    // copy/paste across all apps. Reading it does not require special entitlements on iOS 16+.
    static func readContent() -> PasteboardContent? {
        // Prefer images when both image and text are on the clipboard — keeps screenshots
        // from becoming plain label strings.
        if UIPasteboard.general.hasImages,
           let image = UIPasteboard.general.image,
           let data = image.pngData() {
            return .image(data, uti: UTType.png.identifier)
        }

        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return .text(text)
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
        // UIImage(data:) decodes the raw bytes; assigning to UIPasteboard.image
        // puts the image on the system clipboard in a format other apps can paste.
        if let image = UIImage(data: data) {
            UIPasteboard.general.image = image
        }
    }
}
