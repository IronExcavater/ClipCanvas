import SwiftUI

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
    let toggleSidebar: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if let toggleSidebar {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }

            if selectedCount == 0 {
                Text(workspace?.name ?? "Canvas")
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            if selectedCount > 0 {
                selectionActions
            } else {
                idleActions
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.snappy(duration: 0.18), value: selectedCount > 0)
    }

    // MARK: Selection active — prominent inline buttons

    @ViewBuilder
    private var selectionActions: some View {
        // Badge showing how many cards are selected
        HStack(spacing: 4) {
            Text("\(selectedCount)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
            Text(selectedCount == 1 ? "card" : "cards")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }

        // AI / chat
        Button(action: chat) {
            Image(systemName: "sparkles")
        }
        .help("Ask AI about selection")

        // Copy
        Button(action: copySelected) {
            Image(systemName: "doc.on.doc")
        }
        .help("Copy selected")

        // Transform submenu (kept in a small menu to avoid crowding)
        Menu {
            ForEach(TransformKind.allCases, id: \.self) { kind in
                Button(kind.label) { transform(kind) }
            }
        } label: {
            Image(systemName: "wand.and.sparkles")
        }
        .help("Transform selected")

        // Delete
        Button(role: .destructive, action: deleteSelected) {
            Image(systemName: "trash")
        }
        .help("Delete selected")

        // Deselect — always the last button, acts as a clear affordance
        Button(action: clearSelection) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)   // plain so it doesn't get the bordered style
        .help("Deselect all")

        // Overflow for less common actions
        Menu {
            Button(
                selectedArePrivate ? "Unmark Private" : "Mark Private",
                systemImage: selectedArePrivate ? "lock.open" : "lock",
                action: togglePrivacy
            )
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: Nothing selected — idle actions

    @ViewBuilder
    private var idleActions: some View {
        Button(action: paste) {
            if isNarrow {
                Image(systemName: "doc.on.clipboard")
            } else {
                Label("Clipboard", systemImage: "doc.on.clipboard")
            }
        }
        .help("Add clipboard to canvas")

        Menu {
            Button("New Card", systemImage: "plus", action: addCard)
            Button(
                isChatVisible ? "Hide Chat" : "Chat",
                systemImage: isChatVisible ? "sidebar.right" : "sparkles",
                action: toggleChat
            )
            Divider()
            Button("History", systemImage: "clock", action: openLibrary)
            Button("Settings", systemImage: "gearshape", action: openSettings)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
