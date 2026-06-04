import Foundation

nonisolated enum NoteTextCommandKind: Equatable {
    case bold
    case bullet
    case highlight
}

nonisolated struct NoteTextCommand: Equatable {
    let id = UUID()
    let kind: NoteTextCommandKind
}
