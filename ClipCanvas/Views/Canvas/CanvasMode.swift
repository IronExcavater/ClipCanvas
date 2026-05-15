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
}

enum ZoomCommand: Equatable {
    case zoomIn
    case zoomOut
    case fitContent
    case arrangeAll
    case arrangeSelection
}

nonisolated enum CanvasToolbarItem: Equatable {
    case paste
    case newNote
    case askAI
    case details
    case editContent
    case manageTags
    case arrangeSelection
    case color
    case formatBold
    case formatBullet
    case formatHighlight
    case delete
    case divider
    case mode(CanvasMode)
    case closeMode
    case drawPen
    case drawHighlighter
    case drawEraser
    case drawLasso
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

    var supportsSettings: Bool {
        switch self {
        case .pen, .highlighter, .eraser: true
        case .lasso: false
        }
    }
}

nonisolated struct CanvasToolbarConfiguration: Equatable {
    var items: [CanvasToolbarItem]

    static func make(selectedCount: Int, mode: CanvasMode, isEditing: Bool = false) -> CanvasToolbarConfiguration {
        switch mode {
        case .draw:
            return CanvasToolbarConfiguration(items: [
                .closeMode,
                .drawPen, .drawHighlighter, .drawEraser, .drawLasso
            ])

        case .edit:
            if selectedCount > 0 {
                if isEditing {
                    return CanvasToolbarConfiguration(items: [
                        .closeMode,
                        .formatBold,
                        .formatBullet,
                        .formatHighlight
                    ])
                }
                return CanvasToolbarConfiguration(items: [
                    .closeMode,
                    .editContent,
                    .color, .manageTags,
                    .details, .delete
                ])
            }
            return CanvasToolbarConfiguration(items: [
                .closeMode,
                .newNote, .color,
            ])

        case .pan:
            if selectedCount > 0 {
                return CanvasToolbarConfiguration(items: [
                    .arrangeSelection, .details, .askAI, .delete
                ])
            }
            return CanvasToolbarConfiguration(items: [
                .paste, .newNote, .askAI,
                .divider,
                .mode(.pan), .mode(.edit), .mode(.draw)
            ])
        }
    }

    var preferredWidth: CGFloat {
        CGFloat(items.count * 52 + max(items.count - 1, 0) * 2 + 24)
    }
}
