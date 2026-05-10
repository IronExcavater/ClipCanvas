import SwiftUI

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
