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
    let onArrangeAll: () -> Void
    let onFitContent: () -> Void

    @State private var confirmingClear = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSidebar) {
                Image(systemName: AppSymbol.sidebar)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(BlendedIconButtonStyle())

            Spacer()

            title

            Spacer()

            Menu {
                Button("Rename", systemImage: "pencil", action: onBeginRename)
                Button("Fit View to Content", systemImage: "arrow.up.left.and.arrow.down.right", action: onFitContent)
                Button("Arrange All in Grid", systemImage: "square.grid.2x2", action: onArrangeAll)
                Divider()
                Button("Clear All", systemImage: "trash", role: .destructive) {
                    confirmingClear = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            CanvasTopBarFade()
                .allowsHitTesting(false)
                .ignoresSafeArea(.container, edges: .top)
        }
        .alert("Clear all clips from this workspace?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive, action: onClearAll)
        } message: {
            Text("This removes every clip placement from the current canvas.")
        }
    }

    @ViewBuilder
    private var title: some View {
        if isRenaming {
            TextField("Workspace name", text: $renameText)
                .font(.title3.weight(.semibold))
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
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .onTapGesture(count: 2, perform: onBeginRename)
        }
    }
}

private struct CanvasTopBarFade: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: 132)
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0.86), .black.opacity(0.40), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(y: -54)
    }
}
