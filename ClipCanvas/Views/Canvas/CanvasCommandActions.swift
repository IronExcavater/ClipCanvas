import SwiftUI

struct CanvasCommandActions {
    var canEditSelection: Bool
    var canDeleteSelection: Bool
    var canFormatText: Bool

    let createNote: () -> Void
    let paste: () -> Void
    let askAI: () -> Void
    let search: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let fitContent: () -> Void
    let arrangeSelection: () -> Void
    let editSelection: () -> Void
    let duplicateSelection: () -> Void
    let deleteSelection: () -> Void
    let bold: () -> Void
    let italic: () -> Void
    let underline: () -> Void
    let strikethrough: () -> Void
    let bullet: () -> Void
    let numbered: () -> Void
    let checklist: () -> Void
    let highlight: () -> Void
}

private struct CanvasCommandActionsKey: FocusedValueKey {
    typealias Value = CanvasCommandActions
}

extension FocusedValues {
    var canvasCommandActions: CanvasCommandActions? {
        get { self[CanvasCommandActionsKey.self] }
        set { self[CanvasCommandActionsKey.self] = newValue }
    }
}

struct ClipCanvasCommands: Commands {
    @FocusedValue(\.canvasCommandActions) private var canvasActions

    var body: some Commands {
        CommandMenu("Canvas") {
            Button("New Note") { canvasActions?.createNote() }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(canvasActions == nil)

            Button("Paste to Canvas") { canvasActions?.paste() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(canvasActions == nil)

            Button("Ask AI") { canvasActions?.askAI() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(canvasActions == nil)

            Divider()

            Button("Search Canvas") { canvasActions?.search() }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(canvasActions == nil)

            Button("Zoom In") { canvasActions?.zoomIn() }
                .keyboardShortcut("+", modifiers: [.command])
                .disabled(canvasActions == nil)

            Button("Zoom Out") { canvasActions?.zoomOut() }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(canvasActions == nil)

            Button("Fit Content") { canvasActions?.fitContent() }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(canvasActions == nil)

            Divider()

            Button("Edit Selection") { canvasActions?.editSelection() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(canvasActions?.canEditSelection != true)

            Button("Duplicate Selection") { canvasActions?.duplicateSelection() }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(canvasActions?.canDeleteSelection != true)

            Button("Arrange Selection") { canvasActions?.arrangeSelection() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(canvasActions?.canDeleteSelection != true)

            Button("Delete Selection", role: .destructive) { canvasActions?.deleteSelection() }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(canvasActions?.canDeleteSelection != true)
        }

        CommandMenu("Format") {
            Button("Bold") { canvasActions?.bold() }
                .keyboardShortcut("b", modifiers: [.command])
                .disabled(canvasActions?.canFormatText != true)

            Button("Italic") { canvasActions?.italic() }
                .keyboardShortcut("i", modifiers: [.command])
                .disabled(canvasActions?.canFormatText != true)

            Button("Underline") { canvasActions?.underline() }
                .keyboardShortcut("u", modifiers: [.command])
                .disabled(canvasActions?.canFormatText != true)

            Button("Strikethrough") { canvasActions?.strikethrough() }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                .disabled(canvasActions?.canFormatText != true)

            Button("Bulleted List") { canvasActions?.bullet() }
                .keyboardShortcut("8", modifiers: [.command, .shift])
                .disabled(canvasActions?.canFormatText != true)

            Button("Numbered List") { canvasActions?.numbered() }
                .keyboardShortcut("7", modifiers: [.command, .shift])
                .disabled(canvasActions?.canFormatText != true)

            Button("Checklist") { canvasActions?.checklist() }
                .keyboardShortcut("9", modifiers: [.command, .shift])
                .disabled(canvasActions?.canFormatText != true)

            Button("Highlight") { canvasActions?.highlight() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(canvasActions?.canFormatText != true)
        }
    }
}
