enum CanvasMode: Equatable {
    case pan    // default: drag pans canvas, tap card copies to clipboard
    case select // drag selects, tap card toggles checkmark
    case draw   // PencilKit layer (Phase 2 — mode exists but no drawing yet)
}
