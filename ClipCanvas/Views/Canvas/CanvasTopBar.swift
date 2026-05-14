import SwiftUI

struct CanvasTopBar: View {
    let workspaceName: String
    let workspaces: [Workspace]
    let activeWorkspaceID: UUID
    @Binding var isRenaming: Bool
    @Binding var renameText: String
    var renameFocused: FocusState<Bool>.Binding
    let onToggleSidebar: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onSelectWorkspace: (Workspace) -> Void
    let selectedCount: Int
    let visibleCount: Int
    let onAskAI: () -> Void
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
            }
            .buttonStyle(BlendedIconButtonStyle())

            Spacer()

            title
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    WorkspaceTitleBackdrop()
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isRenaming)
                .animation(.spring(response: 0.24, dampingFraction: 0.86), value: workspaceName)

            Spacer()

            Menu {
                Button(askAITitle, systemImage: "sparkles", action: onAskAI)
                    .disabled(selectedCount == 0 && visibleCount == 0)
                Divider()
                Button("Rename", systemImage: "pencil", action: onBeginRename)
                Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right", action: onFitContent)
                Button("Grid", systemImage: "square.grid.2x2", action: onArrangeAll)
                Divider()
                Button("Clear", systemImage: "trash", role: .destructive) {
                    confirmingClear = true
                }
            } label: {
                AppCircleIconLabel(systemImage: AppSymbol.options)
            }
            .buttonStyle(BlendedIconButtonStyle())
            .accessibilityLabel("Workspace options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            CanvasTopBarFade()
                .allowsHitTesting(false)
                .ignoresSafeArea(.container, edges: .top)
                .offset(y: -118)
        }
        .alert("Clear all cards from this workspace?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive, action: onClearAll)
        } message: {
            Text("This removes every card from the current canvas.")
        }
    }

    private var askAITitle: String {
        selectedCount > 0 ? "Ask About Selection" : "Ask About View"
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
                .onChange(of: renameText) { _, newValue in
                    let limited = WorkspaceNamePolicy.limitedEditingText(newValue)
                    if limited != newValue { renameText = limited }
                }
                .onSubmit(onCommitRename)
                .onDisappear {
                    if isRenaming { onCommitRename() }
                }
                .frame(width: titleWidth(for: renameText))
        } else {
            Menu {
                ForEach(workspaces) { workspace in
                    Button {
                        onSelectWorkspace(workspace)
                    } label: {
                        Label(workspace.name, systemImage: workspace.id == activeWorkspaceID ? "checkmark" : "square")
                    }
                }
                Divider()
                Button("Rename", systemImage: "pencil", action: onBeginRename)
            } label: {
                Text(workspaceName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: titleWidth(for: workspaceName))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in onBeginRename() })
        }
    }

    private func titleWidth(for text: String) -> CGFloat {
        let visibleCharacters = min(max(text.count, 6), WorkspaceNamePolicy.maximumLength)
        let estimated = CGFloat(visibleCharacters) * 12 + 18
        return min(max(estimated, 82), 236)
    }
}

private struct CanvasTopBarFade: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(topContrast)
            .frame(height: 260)
            .mask(fadeMask)
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.00),
                .init(color: .black.opacity(0.98), location: 0.24),
                .init(color: .black.opacity(0.82), location: 0.48),
                .init(color: .black.opacity(0.44), location: 0.72),
                .init(color: .clear, location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topContrast: some View {
        LinearGradient(
            stops: [
                .init(color: Color(uiColor: .systemBackground).opacity(0.32), location: 0.00),
                .init(color: Color(uiColor: .systemBackground).opacity(0.18), location: 0.38),
                .init(color: .clear, location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct WorkspaceTitleBackdrop: View {
    var body: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        }
    }
}
