enum CanvasMode: Equatable {
    case pan    // default: drag pans canvas, tap object selects it
    case draw   // PencilKit layer (Phase 2 — mode exists but no drawing yet)
}

enum ZoomCommand: Equatable {
    case zoomIn
    case zoomOut
    case fitContent
    case arrangeAll
    case arrangeSelection
}
