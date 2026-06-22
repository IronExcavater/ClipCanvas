import SwiftUI

struct CanvasTopBar: View {
    @Binding var isRenaming: Bool
    @Binding var renameText: String
    var renameFocused: FocusState<Bool>.Binding
    let onToggleSidebar: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let selectedCount: Int
    let visibleCount: Int
    let shareSelectionText: String
    let shareVisibleText: String
    let shareWorkspaceText: String
    let shareWorkspaceURL: URL?
    let shareImageURLs: [URL]
    let onAskAI: () -> Void
    let workspaceName: String
    let onClearAll: () -> Void
    let onArrangeAll: () -> Void
    let onFitContent: () -> Void
    var onSearch: (() -> Void)? = nil
    var showsSidebarButton = true

    private func titleMaxWidth(in totalWidth: CGFloat) -> CGFloat {
        let horizontalPadding: CGFloat = 32
        let sideControls: CGFloat = (showsSidebarButton ? 46 : 0) + 100
        let hStackSpacing: CGFloat = 12 * 2
        let minimumSpacerRoom: CGFloat = 16
        let available = totalWidth - horizontalPadding - sideControls - hStackSpacing - minimumSpacerRoom
        return max(118, available)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 12) {
                    if showsSidebarButton {
                        Button(action: onToggleSidebar) {
                            Image(systemName: AppSymbol.sidebar)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(BlendedIconButtonStyle())
                        .frame(width: 46)
                    }

                    Spacer(minLength: 0)

                    actionCapsule
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
    private func titleButton(maxWidth: CGFloat) -> some View {
        Button(action: onBeginRename) {
            Text(workspaceName)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
                .frame(width: maxWidth)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background { WorkspaceTitleBackdrop() }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rename workspace")
    }

    @ViewBuilder
    private func titleEditor(maxWidth: CGFloat) -> some View {
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
    }

    private var actionCapsule: some View {
        HStack(spacing: 2) {
            shareMenu
            Divider()
                .frame(height: 22)
                .opacity(0.45)
            overflowMenu
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .background {
            AppGlassSurface(
                shape: .capsule,
                fallback: .color(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground)),
                interactive: true,
                stroke: Color.primary.opacity(0.06)
            )
        }
        .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }

    private var shareMenu: some View {
        Menu {
            if let shareWorkspaceURL {
                ShareLink(item: shareWorkspaceURL) {
                    Label("Share ClipCanvas Workspace", systemImage: "person.2.wave.2")
                }
            }
            ShareLink(item: shareWorkspaceText) {
                Label("Share Workspace Text", systemImage: "rectangle.3.group")
            }
            ShareLink(item: shareVisibleText) {
                Label("Share Visible Cards", systemImage: "rectangle.stack")
            }
            ShareLink(item: shareSelectionText) {
                Label("Share Selection", systemImage: "square.and.arrow.up")
            }
            .disabled(selectedCount == 0)
            if !shareImageURLs.isEmpty {
                ShareLink(items: shareImageURLs) {
                    Label("Share Images", systemImage: "photo.on.rectangle")
                }
            }
        } label: {
            AppCircleIconLabel(systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share canvas")
        .frame(width: 42, height: 42)
    }

    private var overflowMenu: some View {
        Menu {
            Button(askAITitle, systemImage: "sparkles", action: onAskAI)
                .disabled(selectedCount == 0 && visibleCount == 0)
            if let onSearch {
                Button("Search Canvas", systemImage: "magnifyingglass", action: onSearch)
            }
            Button("Fit Content", systemImage: "arrow.up.left.and.arrow.down.right", action: onFitContent)
            Button("Arrange Grid", systemImage: "square.grid.2x2", action: onArrangeAll)
            Button("Clear Canvas", systemImage: "trash", role: .destructive, action: onClearAll)
        } label: {
            AppCircleIconLabel(systemImage: AppSymbol.options)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Workspace options")
        .frame(width: 42, height: 42)
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
