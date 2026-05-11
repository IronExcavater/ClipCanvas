import SwiftUI

// WorkspaceTopBar is a pure display component — it receives all state and callbacks from
// WorkspaceView and never reads from the environment or performs its own model mutations.
struct WorkspaceTopBar: View {
    let workspace: Workspace?
    let selectedCount: Int
    let isNarrow: Bool
    let isChatVisible: Bool
    let paste: () -> Void
    let addCard: () -> Void
    let transform: (TransformKind) -> Void
    let chat: () -> Void
    let copySelected: () -> Void
    let deleteSelected: () -> Void
    let clearSelection: () -> Void
    let selectedArePrivate: Bool
    let togglePrivacy: () -> Void
    let toggleChat: () -> Void
    let openLibrary: () -> Void
    let openSettings: () -> Void
    let toggleSidebar: (() -> Void)?   // nil on wide layouts where the sidebar is always visible

    var body: some View {
        HStack(spacing: 10) {
            if let toggleSidebar {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }

            Text(workspace?.name ?? "Canvas")
                .font(.headline)
                .lineLimit(1)

            Spacer()

            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                // On narrow (phone) screens show just the icon; on wide screens show a label too.
                Button(action: chat) {
                    if isNarrow {
                        Image(systemName: "bubble.left.and.bubble.right")
                    } else {
                        Label("Ask", systemImage: "bubble.left.and.bubble.right")
                    }
                }
                .help("Ask about selection")
            } else {
                Button(action: paste) {
                    if isNarrow {
                        Image(systemName: "doc.on.clipboard")
                    } else {
                        Label("Clipboard", systemImage: "doc.on.clipboard")
                    }
                }
                .help("Add clipboard to canvas")
            }

            WorkspaceActionMenu(
                selectedCount: selectedCount,
                isChatVisible: isChatVisible,
                selectedArePrivate: selectedArePrivate,
                addCard: addCard,
                transform: transform,
                copySelected: copySelected,
                deleteSelected: deleteSelected,
                clearSelection: clearSelection,
                togglePrivacy: togglePrivacy,
                toggleChat: toggleChat,
                openLibrary: openLibrary,
                openSettings: openSettings
            )
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)   // adaptive material that matches the system toolbar appearance
    }
}

private struct WorkspaceActionMenu: View {
    let selectedCount: Int
    let isChatVisible: Bool
    let selectedArePrivate: Bool
    let addCard: () -> Void
    let transform: (TransformKind) -> Void
    let copySelected: () -> Void
    let deleteSelected: () -> Void
    let clearSelection: () -> Void
    let togglePrivacy: () -> Void
    let toggleChat: () -> Void
    let openLibrary: () -> Void
    let openSettings: () -> Void

    var body: some View {
        Menu {
            if selectedCount > 0 {
                selectionActions
            } else {
                emptySelectionActions
            }
            Button("History", systemImage: "clock", action: openLibrary)
            Button("Settings", systemImage: "gearshape", action: openSettings)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // @ViewBuilder lets a computed property return different view types from each branch.
    @ViewBuilder
    private var selectionActions: some View {
        Menu("Transform", systemImage: "wand.and.sparkles") {
            ForEach(TransformKind.allCases, id: \.self) { kind in
                Button(kind.label) { transform(kind) }
            }
        }
        Button("Copy", systemImage: "doc.on.doc", action: copySelected)
        Button(
            selectedArePrivate ? "Unmark Private" : "Mark Private",
            systemImage: selectedArePrivate ? "lock.open" : "lock",
            action: togglePrivacy
        )
        Button("Clear Selection", systemImage: "xmark.circle", action: clearSelection)
        Button("Delete", systemImage: "trash", role: .destructive, action: deleteSelected)
        Divider()
    }

    @ViewBuilder
    private var emptySelectionActions: some View {
        Button("New Card", systemImage: "plus", action: addCard)
        Button(
            isChatVisible ? "Hide Chat" : "Show Chat",
            systemImage: isChatVisible ? "sidebar.right" : "sparkles",
            action: toggleChat
        )
        Divider()
    }
}
