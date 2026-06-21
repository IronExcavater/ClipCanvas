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
    var onSearch: (() -> Void)? = nil

    private func titleMaxWidth(in totalWidth: CGFloat, editing: Bool) -> CGFloat {
        let horizontalPadding: CGFloat = 32
        let sideControls: CGFloat = 46 * 2
        let hStackSpacing: CGFloat = 12 * 2
        let minimumSpacerRoom: CGFloat = 16
        let available = totalWidth - horizontalPadding - sideControls - hStackSpacing - minimumSpacerRoom
        return editing ? max(118, available) : max(82, min(180, available))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 12) {
                    Button(action: onToggleSidebar) {
                        Image(systemName: AppSymbol.sidebar)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(BlendedIconButtonStyle())
                    .frame(width: 46)

                    Spacer(minLength: 8)

                    title(maxWidth: titleMaxWidth(in: proxy.size.width, editing: isRenaming))
                        .layoutPriority(1)
                        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isRenaming)
                        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: workspaceName)

                    Spacer(minLength: 8)

                    Menu {
                        Button(askAITitle, systemImage: "sparkles", action: onAskAI)
                            .disabled(selectedCount == 0 && visibleCount == 0)
                        if let onSearch {
                            Button("Search Canvas", systemImage: "magnifyingglass", action: onSearch)
                        }
                        Button("Fit Content", systemImage: "arrow.up.left.and.arrow.down.right", action: onFitContent)
                        Button("Arrange Grid", systemImage: "square.grid.2x2", action: onArrangeAll)
                        Button("Rename Workspace", systemImage: "pencil", action: onBeginRename)
                        Button("Clear Canvas", systemImage: "trash", role: .destructive, action: onClearAll)
                    } label: {
                        AppCircleIconLabel(systemImage: AppSymbol.options)
                    }
                    .buttonStyle(BlendedIconButtonStyle())
                    .accessibilityLabel("Workspace options")
                    .frame(width: 46)
                }
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            CanvasTopBarFade()
                .allowsHitTesting(false)
                .ignoresSafeArea(.container, edges: .top)
                .offset(y: -118)
        }
    }

    private var askAITitle: String {
        selectedCount > 0 ? "Ask About Selection" : "Ask About View"
    }

    @ViewBuilder
    private func title(maxWidth: CGFloat) -> some View {
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
                .frame(width: maxWidth)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background { WorkspaceTitleBackdrop() }
        } else {
            Menu {
                ForEach(workspaces) { workspace in
                    Button {
                        onSelectWorkspace(workspace)
                    } label: {
                        Label(
                            workspace.name,
                            systemImage: workspace.id == activeWorkspaceID ? "checkmark" : "folder"
                        )
                    }
                }
                Button("Rename", systemImage: "pencil", action: onBeginRename)
            } label: {
                workspaceTitleLabel(maxWidth: maxWidth)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in onBeginRename() })
        }
    }

    private func workspaceTitleLabel(maxWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            workspaceTitleText
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background { WorkspaceTitleBackdrop() }
                .fixedSize(horizontal: true, vertical: false)

            workspaceTitleText
                .frame(width: maxWidth - 28)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background { WorkspaceTitleBackdrop() }
        }
        .frame(maxWidth: maxWidth)
    }

    private var workspaceTitleText: some View {
        Text(workspaceName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
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
                .init(color: Color.platformSystemBackground.opacity(0.32), location: 0.00),
                .init(color: Color.platformSystemBackground.opacity(0.18), location: 0.38),
                .init(color: .clear, location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct WorkspaceTitleBackdrop: View {
    var body: some View {
        Color.clear.glassCapsule()
    }
}
