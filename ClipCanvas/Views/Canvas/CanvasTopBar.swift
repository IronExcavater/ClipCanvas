import SwiftUI

struct CanvasTopBar: View {
    let workspaceName: String
    @Binding var isRenaming: Bool
    @Binding var renameText: String
    var renameFocused: FocusState<Bool>.Binding
    let onToggleSidebar: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            title

            Spacer()

            Button(role: .destructive, action: onClearAll) {
                Image(systemName: "trash")
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(.regularMaterial, ignoresSafeAreaEdges: .top)
    }

    @ViewBuilder
    private var title: some View {
        if isRenaming {
            TextField("Workspace name", text: $renameText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused(renameFocused)
                .submitLabel(.done)
                .onSubmit(onCommitRename)
                .onDisappear {
                    if isRenaming { onCommitRename() }
                }
                .frame(maxWidth: 220)
        } else {
            Text(workspaceName)
                .font(.headline)
                .lineLimit(1)
                .onTapGesture(count: 2, perform: onBeginRename)
        }
    }
}
