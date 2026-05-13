nonisolated enum CanvasMode: Equatable, CaseIterable {
    case normal // default: drag pans canvas, tap object selects it
    case edit   // text and sticky-note editing become primary
    case draw   // PencilKit layer (Phase 2 - mode exists but no drawing yet)

    var systemImage: String {
        switch self {
        case .normal: "hand.point.up.left"
        case .edit: "text.cursor"
        case .draw: "pencil.tip"
        }
    }

    var allowsCanvasPan: Bool {
        self == .normal
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
    case openLink
    case details
    case manageTags
    case arrangeSelection
    case delete
    case divider
    case mode(CanvasMode)
}

nonisolated struct CanvasToolbarConfiguration: Equatable {
    var items: [CanvasToolbarItem]

    static func make(selectedCount: Int, canOpenLink: Bool) -> CanvasToolbarConfiguration {
        if selectedCount > 0 {
            var selectionItems: [CanvasToolbarItem] = [.copy]
            if canOpenLink {
                selectionItems.append(.openLink)
            }
            selectionItems.append(contentsOf: [
                .divider,
                .details,
                .manageTags,
                .arrangeSelection,
                .divider,
                .delete
            ])
            return CanvasToolbarConfiguration(items: selectionItems)
        }

        return CanvasToolbarConfiguration(items: [
            .paste,
            .divider,
            .mode(.normal),
            .mode(.edit),
            .mode(.draw)
        ])
    }
}
