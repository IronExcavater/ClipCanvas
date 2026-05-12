enum CanvasMode: Equatable {
    case pan    // default: drag pans canvas, tap card copies to clipboard
    case draw   // PencilKit layer (Phase 2 — mode exists but no drawing yet)
}

enum ZoomCommand: Equatable {
    case zoomIn
    case zoomOut
    case fitContent
}
