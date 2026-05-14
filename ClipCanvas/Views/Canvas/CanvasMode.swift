import CoreGraphics

nonisolated enum CanvasMode: Equatable, CaseIterable {
    case pan    // drag pans, tap selects
    case edit   // tap opens inline editing
    case draw   // PencilKit layer

    var systemImage: String {
        switch self {
        case .pan:  "hand.point.up.left"
        case .edit: "text.cursor"
        case .draw: "pencil.tip"
        }
    }

    var allowsCanvasPan: Bool { self == .pan }
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
    case askAI
    case details
    case editContent
    case manageTags
    case arrangeSelection
    case bullet
    case color
    case done
    case delete
    case divider
    case mode(CanvasMode)
    case drawPen
    case drawHighlighter
    case drawEraser
    case drawLasso
    case drawConvert
    case drawSave
    case drawClear
}

nonisolated struct CanvasToolbarConfiguration: Equatable {
    var items: [CanvasToolbarItem]

    static func make(selectedCount: Int, mode: CanvasMode, isEditing: Bool = false) -> CanvasToolbarConfiguration {
        switch mode {
        case .draw:
            return CanvasToolbarConfiguration(items: [
                .mode(.pan), .mode(.edit), .mode(.draw),
                .divider,
                .drawPen, .drawHighlighter, .drawEraser, .drawLasso,
                .divider,
                .drawConvert, .drawClear
            ])

        case .edit:
            if selectedCount > 0 {
                if isEditing {
                    return CanvasToolbarConfiguration(items: [
                        .editContent,
                        .divider,
                        .bullet, .color,
                        .divider,
                        .done
                    ])
                }
                return CanvasToolbarConfiguration(items: [
                    .editContent,
                    .divider,
                    .color, .manageTags,
                    .divider,
                    .delete
                ])
            }
            return CanvasToolbarConfiguration(items: [
                .paste,
                .divider,
                .mode(.pan), .mode(.edit), .mode(.draw)
            ])

        case .pan:
            if selectedCount > 0 {
                return CanvasToolbarConfiguration(items: [
                    .askAI,
                    .divider,
                    .arrangeSelection, .details,
                    .divider,
                    .delete
                ])
            }
            return CanvasToolbarConfiguration(items: [
                .paste,
                .divider,
                .mode(.pan), .mode(.edit), .mode(.draw)
            ])
        }
    }

    var preferredWidth: CGFloat {
        CGFloat(items.count * 52 + max(items.count - 1, 0) * 2 + 24)
    }
}
