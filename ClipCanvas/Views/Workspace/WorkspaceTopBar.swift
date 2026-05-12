import SwiftUI

struct WorkspaceTopBar: View {
    let workspace: Workspace?
    let isChatVisible: Bool
    let toggleChat: () -> Void
    let openHistory: () -> Void
    let openSettings: () -> Void
    let toggleSidebar: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if let toggleSidebar {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }

            Text(workspace?.name ?? "Canvas")
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Menu {
                Button(
                    isChatVisible ? "Hide Chat" : "Chat",
                    systemImage: isChatVisible ? "sidebar.right" : "sparkles",
                    action: toggleChat
                )
                Divider()
                Button("History", systemImage: "clock", action: openHistory)
                Button("Settings", systemImage: "gearshape", action: openSettings)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
