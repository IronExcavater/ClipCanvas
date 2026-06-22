import CoreGraphics

nonisolated enum CanvasMode: Equatable, CaseIterable {
    case pan    // drag pans, tap selects
    case edit   // tap opens inline editing
    case draw   // PencilKit layer

    var systemImage: String {
        switch self {
        case .pan:  "hand.raised.fill"
        case .edit: "pencil"
        case .draw: "scribble.variable"
        }
    }

    var allowsCanvasPan: Bool { self != .draw }

    var label: String {
        switch self {
        case .pan: "Select"
        case .edit: "Card"
        case .draw: "Draw"
        }
    }
}

enum ZoomCommand: Equatable {
    case zoomIn
    case zoomOut
    case fitContent
    case arrangeAll
    case arrangeSelection
}

nonisolated enum CanvasToolbarItem: Hashable {
    case paste
    case newNote
    case insertImage
    case askAI
    case details
    case editContent
    case manageTags
    case arrangeSelection
    case duplicate
    case color
    case copyToClipboard
    case pasteFromClipboard
    case formatPanel
    case formatList
    case formatQuote
    case formatLink
    case formatOutdent
    case formatIndent
    case formatBold
    case formatItalic
    case formatUnderline
    case formatStrikethrough
    case formatHighlight
    case delete
    case divider
    case mode(CanvasMode)
    case closeMode
    case drawPen
    case drawHighlighter
    case drawEraser
    case drawLasso

    var label: String {
        switch self {
        case .paste: "Paste"
        case .newNote: "Card"
        case .insertImage: "Insert Image"
        case .askAI: "Ask AI"
        case .details: "Details"
        case .editContent: "Edit"
        case .manageTags: "Tags"
        case .arrangeSelection: "Arrange"
        case .duplicate: "Duplicate"
        case .color: "Color"
        case .copyToClipboard: "Copy to Clipboard"
        case .pasteFromClipboard: "Paste from Clipboard"
        case .formatPanel: "Format"
        case .formatList: "List"
        case .formatQuote: "Quote"
        case .formatLink: "Link"
        case .formatOutdent: "Outdent"
        case .formatIndent: "Indent"
        case .formatBold: "Bold"
        case .formatItalic: "Italic"
        case .formatUnderline: "Underline"
        case .formatStrikethrough: "Strikethrough"
        case .formatHighlight: "Highlight"
        case .delete: "Delete"
        case .divider: "Divider"
        case .mode(let mode): mode.label
        case .closeMode: "Close"
        case .drawPen: CanvasDrawTool.pen.displayName
        case .drawHighlighter: CanvasDrawTool.highlighter.displayName
        case .drawEraser: CanvasDrawTool.eraser.displayName
        case .drawLasso: CanvasDrawTool.lasso.displayName
        }
    }
}

nonisolated enum CanvasSelectionKind: Equatable {
    case none
    case text
    case clip
    case image
    case mixed
}

nonisolated enum CanvasDrawTool: Equatable {
    case pen
    case highlighter
    case eraser
    case lasso

    var systemImage: String {
        switch self {
        case .pen: "pencil"
        case .highlighter: "highlighter"
        case .eraser: "eraser.fill"
        case .lasso: "lasso"
        }
    }

    var displayName: String {
        switch self {
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }

    var supportsSettings: Bool {
        switch self {
        case .pen, .highlighter, .eraser: true
        case .lasso: false
        }
    }
}

nonisolated struct CanvasToolbarConfiguration: Hashable {
    var items: [CanvasToolbarItem]

    static func make(
        selectedCount: Int,
        mode: CanvasMode,
        selectionKind: CanvasSelectionKind = .none,
        isEditing: Bool = false
    ) -> CanvasToolbarConfiguration {
        if isEditing {
            return CanvasToolbarConfiguration(items: [
                .closeMode,
                .formatPanel,
                .formatList,
                .formatQuote,
                .formatLink,
                .formatOutdent,
                .formatIndent,
                .color,
                .formatBold,
                .formatItalic,
                .formatUnderline,
                .formatStrikethrough,
                .formatHighlight
            ])
        }

        switch mode {
        case .draw:
            return CanvasToolbarConfiguration(items: [
                .closeMode,
                .drawPen, .drawHighlighter, .drawEraser, .drawLasso
            ])

        case .edit:
            return CanvasToolbarConfiguration(items: [
                .askAI,
                .paste,
                .closeMode,
                .newNote,
                .insertImage,
            ])

        case .pan:
            return CanvasToolbarConfiguration(items: selectedCount > 0 ? [
                .askAI,
                .copyToClipboard
            ] + (selectedCount == 1
                ? (selectionKind == .text || selectionKind == .clip
                    ? [.editContent, .details, .arrangeSelection, .delete]
                    : [.details, .arrangeSelection, .delete])
                : [.arrangeSelection, .delete])
                : [.askAI, .paste, .newNote, .insertImage, .mode(.draw)])
        }
    }

    var preferredWidth: CGFloat {
        CGFloat(items.count * 44 + max(items.count - 1, 0) * 2 + 20)
    }
}
