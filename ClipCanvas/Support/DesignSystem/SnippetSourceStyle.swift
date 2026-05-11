import SwiftUI

// SourceGlyph renders the coloured icon shown in card headers and sidebar rows.
// The icon and colour are derived from how and what the snippet was captured.
struct SourceGlyph: View {
    let snippet: Snippet?

    var body: some View {
        Image(systemName: snippet?.sourceIcon ?? "doc.text")
            .font(.caption.weight(.semibold))
            .foregroundStyle(snippet?.cardVariant.accent ?? .secondary)
            .frame(width: 28, height: 28)
            .background(snippet?.cardVariant.background ?? Color.clipCanvasSecondaryBackground, in: RoundedRectangle(cornerRadius: 7))
    }
}

// These computed properties expose display metadata derived from the snippet's
// capture method and content type. Keeping them here (not in the @Model) avoids
// mixing UI concerns into the data layer.
extension Snippet {
    var sourceTitle: String {
        switch captureMethod {
        case .transformResult: "Result"
        case .quickAction: "Clipboard"
        case .appIntent: "Shortcut"
        case .manualPaste: type.sourceTitle
        }
    }

    var sourceDetail: String {
        switch captureMethod {
        case .transformResult: "Generated"
        case .quickAction: "Auto captured"
        case .appIntent: "Quick action"
        case .manualPaste: type == .image ? "Screenshot" : "Manual"
        }
    }

    var sourceIcon: String {
        switch captureMethod {
        case .transformResult: "wand.and.sparkles"
        case .quickAction: "doc.on.clipboard"
        case .appIntent: "sparkles.rectangle.stack"
        case .manualPaste: type.icon
        }
    }

    // Maps each capture method and content type to a card colour variant.
    var cardVariant: CardColor {
        switch captureMethod {
        case .transformResult: .green
        case .quickAction, .appIntent: .blue
        case .manualPaste: type.cardVariant
        }
    }
}

private extension SnippetType {
    var sourceTitle: String {
        switch self {
        case .code: "Code"
        case .url: "Link"
        case .image: "Image"
        case .text: "Text"
        }
    }

    var cardVariant: CardColor {
        switch self {
        case .code: .purple
        case .url: .yellow
        case .image: .pink
        case .text: .default
        }
    }
}
