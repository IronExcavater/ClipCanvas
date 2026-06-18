import SwiftUI

struct MarkdownPreview: View {
    let text: String
    var emptyText = " "
    private static let orderedListPattern = try? NSRegularExpression(pattern: #"^\d+\.\s+"#)

    var body: some View {
        let blocks = Self.blocks(for: text, emptyText: emptyText)
        if blocks.count == 1, case .paragraph(let content) = blocks[0].kind {
            Text(Self.attributedString(for: content, emptyText: emptyText))
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(blocks) { block in
                    switch block.kind {
                    case .paragraph(let content):
                        Text(Self.attributedString(for: content, emptyText: emptyText))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .bullet(let content, let level):
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("•")
                                .fontWeight(.semibold)
                                .frame(width: 10, alignment: .center)
                            Text(Self.attributedString(for: content, emptyText: emptyText))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, CGFloat(level) * 16)
                    case .empty:
                        Text(" ")
                    }
                }
            }
        }
    }

    static func attributedString(for text: String, emptyText: String = " ") -> AttributedString {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyText : text
        if let attributed = try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(source)
    }

    static func blocks(for text: String, emptyText: String = " ") -> [MarkdownPreviewBlock] {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyText : text
        let lines = source.components(separatedBy: .newlines)
        return lines.enumerated().map { index, line in
            let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let trimmedNS = trimmed as NSString
            if trimmed.isEmpty {
                return MarkdownPreviewBlock(index: index, kind: .empty)
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let body = (trimmed as NSString).substring(from: 2)
                return MarkdownPreviewBlock(
                    index: index,
                    kind: .bullet(body, level: min(leadingWhitespace / 2, 3))
                )
            }
            if let match = Self.orderedListPattern?.firstMatch(
                in: trimmed,
                range: NSRange(location: 0, length: trimmedNS.length)
            ), match.range.location == 0 {
                let body = trimmedNS.substring(from: match.range.length)
                return MarkdownPreviewBlock(
                    index: index,
                    kind: .bullet(body, level: min(leadingWhitespace / 2, 3))
                )
            }
            return MarkdownPreviewBlock(index: index, kind: .paragraph(line))
        }
    }
}

struct MarkdownPreviewBlock: Identifiable {
    let index: Int
    let kind: Kind

    var id: Int { index }

    enum Kind {
        case paragraph(String)
        case bullet(String, level: Int)
        case empty
    }
}
