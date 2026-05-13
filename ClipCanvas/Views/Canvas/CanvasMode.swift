nonisolated enum CanvasMode: Equatable, CaseIterable {
    case pan    // default: drag pans canvas, tap object selects it
    case edit   // text and sticky-note editing become primary
    case draw   // PencilKit layer (Phase 2 - mode exists but no drawing yet)

    var systemImage: String {
        switch self {
        case .pan: "hand.point.up.left"
        case .edit: "text.cursor"
        case .draw: "pencil.tip"
        }
    }

    var allowsCanvasPan: Bool {
        self == .pan
    }
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
    case copy
    case details
    case editContent
    case manageTags
    case arrangeSelection
    case delete
    case divider
    case mode(CanvasMode)
}

nonisolated struct CanvasToolbarConfiguration: Equatable {
    var items: [CanvasToolbarItem]

    static func make(selectedCount: Int, mode: CanvasMode) -> CanvasToolbarConfiguration {
        if selectedCount > 0 {
            switch mode {
            case .pan:
                return CanvasToolbarConfiguration(items: [
                    .copy,
                    .divider,
                    .details,
                    .arrangeSelection
                ])
            case .edit:
                return CanvasToolbarConfiguration(items: [
                    .editContent,
                    .divider,
                    .manageTags,
                    .delete
                ])
            case .draw:
                return CanvasToolbarConfiguration(items: [
                    .details,
                    .divider,
                    .delete
                ])
            }
        }

        return CanvasToolbarConfiguration(items: [
            .paste,
            .divider,
            .mode(.pan),
            .mode(.edit),
            .mode(.draw)
        ])
    }
}
