import SwiftUI
import SwiftData

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void

    @Environment(\.modelContext) private var context
    @State private var mode: CanvasMode = .pan
    @State private var feedback: String?
    @State private var zoomCommand: ZoomCommand?
    @State private var selectedPlacementIDs: Set<UUID> = []
    @State private var detailClip: Clip?
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
                onCopyClip: copyToClipboard
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CanvasTopBar(
                    workspaceName: workspace.name,
                    isRenaming: $isRenaming,
                    renameText: $renameText,
                    renameFocused: $renameFocused,
                    onToggleSidebar: onToggleSidebar,
                    onBeginRename: beginRename,
                    onCommitRename: commitRename,
                    onClearAll: clearAll
                )

                Spacer()

                if !selectedPlacementIDs.isEmpty {
                    CanvasSelectionBar(
                        selectedCount: selectedPlacementIDs.count,
                        onCopy: copySelected,
                        onDetails: showSelectedDetails,
                        onDelete: deleteSelected,
                        onClear: { selectedPlacementIDs.removeAll() }
                    )
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                CanvasToolbar(
                    mode: $mode,
                    onPaste: paste,
                    onZoomIn: { zoomCommand = .zoomIn },
                    onZoomOut: { zoomCommand = .zoomOut },
                    onFitContent: { zoomCommand = .fitContent }
                )
            }

            if let feedback {
                VStack {
                    Spacer().frame(height: 70)
                    FeedbackBanner(message: feedback)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: feedback != nil)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: selectedPlacementIDs)
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
    }

    // MARK: - Clipboard

    private func paste() {
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        workspace.place(clip: clip)
        showFeedback("Pasted")
    }

    private func copyToClipboard(_ clip: Clip) {
        guard copyClipOnTap else { return }
        ClipboardService.write(clip: clip)
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
        if !trimmed.isEmpty { workspace.name = trimmed }
        isRenaming = false
        renameFocused = false
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
        let texts = clips.map(\.content).filter { !$0.isEmpty }
        guard !texts.isEmpty else { return }
        ClipboardService.writeString(texts.joined(separator: "\n\n"))
        showFeedback(clips.count == 1 ? "Copied 1 clip" : "Copied \(clips.count) clips")
    }

    private func showSelectedDetails() {
        detailClip = selectedClips.first
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

    // MARK: - Feedback

    private func showFeedback(_ msg: String) {
        withAnimation { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
    }
}

private struct CanvasSelectionBar: View {
    let selectedCount: Int
    let onCopy: () -> Void
    let onDetails: () -> Void
    let onDelete: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("\(selectedCount)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())

            Button(action: onCopy) { Image(systemName: "doc.on.doc") }
            Button(action: onDetails) { Image(systemName: "info.circle") }
                .disabled(selectedCount != 1)
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
            Button(action: onClear) { Image(systemName: "xmark") }
        }
        .font(.system(size: 17, weight: .medium))
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
    }
}
