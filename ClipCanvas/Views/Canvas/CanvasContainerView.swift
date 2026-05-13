import SwiftUI
import SwiftData

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void

    @Environment(\.modelContext) private var context
    @State private var mode: CanvasMode = .pan
    @State private var feedback: String?
    @State private var feedbackToken = UUID()
    @State private var zoomCommand: ZoomCommand?
    @State private var visibleScale: CGFloat = 1
    @State private var visibleViewportCenter: CGPoint = .zero
    @State private var selectedPlacementIDs: Set<UUID> = []
    @State private var detailClip: Clip?
    @State private var tagEditSelection: ClipTagEditSelection?
    @State private var isRenaming = false
    @State private var renameText = ""
    @AppStorage("settings.copyClipOnTap") private var copyClipOnTap = true
    @FocusState private var renameFocused: Bool

    var body: some View {
        ZStack {
            CanvasView(
                workspace: workspace,
                mode: mode,
                zoomCommand: $zoomCommand,
                selectedPlacementIDs: $selectedPlacementIDs,
                visibleScale: $visibleScale,
                visibleViewportCenter: $visibleViewportCenter,
                onCopyClip: copyToClipboard
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CanvasTopBar(
                    workspaceName: workspace.name,
                    isRenaming: $isRenaming,
                    renameText: $renameText,
                    renameFocused: $renameFocused,
                    onToggleSidebar: toggleSidebar,
                    onBeginRename: beginRename,
                    onCommitRename: commitRename,
                    onClearAll: clearAll,
                    onArrangeAll: { zoomCommand = .arrangeAll },
                    onFitContent: { zoomCommand = .fitContent }
                )

                Spacer()

                HStack {
                    Spacer()
                    CanvasZoomControls(
                        scale: visibleScale,
                        onZoomIn: { zoomCommand = .zoomIn },
                        onZoomOut: { zoomCommand = .zoomOut }
                    )
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
                }

                CanvasToolbar(
                    mode: $mode,
                    selectedCount: selectedPlacementIDs.count,
                    canOpenLink: selectedOpenableClip != nil,
                    onPaste: paste,
                    onCopy: copySelected,
                    onOpenLink: openSelectedLink,
                    onDetails: showSelectedDetails,
                    onDelete: deleteSelected,
                    onArrangeSelection: { zoomCommand = .arrangeSelection },
                    onManageTags: showSelectedTags
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)

            if let selection = tagEditSelection {
                CanvasTagPanel(
                    clips: selection.clips,
                    onDismiss: { tagEditSelection = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(8)
            }

            VStack {
                Spacer().frame(height: 70)
                FeedbackBanner(message: feedback ?? "")
                    .opacity(feedback == nil ? 0 : 1)
                    .offset(y: feedback == nil ? -12 : 0)
                    .scaleEffect(feedback == nil ? 0.96 : 1)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: feedback)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: selectedPlacementIDs)
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Clipboard

    private func paste() {
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        workspace.place(clip: clip, at: workspace.nextPosition(around: visibleViewportCenter))
        showFeedback("Pasted")
    }

    private func copyToClipboard(_ clip: Clip) {
        guard copyClipOnTap else { return }
        ClipActionService.copy(clip)
        showFeedback("Copied")
    }

    // MARK: - Rename

    private func beginRename() {
        renameText = workspace.name
        isRenaming = true
        renameFocused = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            WorkspaceActionService.rename(workspace, to: trimmed)
        }
        isRenaming = false
        renameFocused = false
    }

    private func toggleSidebar() {
        if isRenaming { commitRename() }
        onToggleSidebar()
    }

    // MARK: - Workspace actions

    private func clearAll() {
        let toDelete = workspace.placements
        toDelete.forEach { context.delete($0) }
        workspace.updatedAt = Date()
        selectedPlacementIDs.removeAll()
        showFeedback(toDelete.isEmpty ? "Canvas is already empty" : "Canvas cleared")
    }

    private func copySelected() {
        let clips = selectedClips
        guard !clips.isEmpty else { return }
        ClipActionService.copy(clips)
        showFeedback(clips.count == 1 ? "Copied 1 clip" : "Copied \(clips.count) clips")
    }

    private func showSelectedDetails() {
        detailClip = selectedClips.first
    }

    private func openSelectedLink() {
        guard let clip = selectedOpenableClip else { return }
        ClipActionService.openURL(for: clip)
    }

    private func showSelectedTags() {
        let clips = selectedClips
        guard !clips.isEmpty else { return }
        tagEditSelection = ClipTagEditSelection(clips: clips)
    }

    private func deleteSelected() {
        let selected = workspace.placements.filter { selectedPlacementIDs.contains($0.id) }
        selected.forEach { context.delete($0) }
        workspace.updatedAt = Date()
        selectedPlacementIDs.removeAll()
        showFeedback(selected.count == 1 ? "Deleted 1 clip" : "Deleted \(selected.count) clips")
    }

    private var selectedClips: [Clip] {
        workspace.placements
            .filter { selectedPlacementIDs.contains($0.id) }
            .compactMap(\.clip)
    }

    private var selectedOpenableClip: Clip? {
        guard selectedClips.count == 1, let clip = selectedClips.first else { return nil }
        return ClipActionService.openableURL(for: clip) == nil ? nil : clip
    }

    // MARK: - Feedback

    private func showFeedback(_ msg: String) {
        let token = UUID()
        feedbackToken = token
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            feedback = msg
        }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            await MainActor.run {
                guard feedbackToken == token else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    feedback = nil
                }
            }
        }
    }
}

private struct ClipTagEditSelection: Identifiable {
    let id = UUID()
    let clips: [Clip]
}
