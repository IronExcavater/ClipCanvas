import SwiftUI
import SwiftData

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void

    @Environment(\.modelContext) private var context
    @State private var mode: CanvasMode = .pan
    @State private var selectedIDs: Set<UUID> = []
    @State private var feedback: String?
    @State private var lastClipboardFingerprint: String?

    var body: some View {
        ZStack {
            CanvasView(
                workspace: workspace,
                mode: mode,
                selectedIDs: $selectedIDs,
                onCopyClip: copyToClipboard,
                onSelectModeEntry: enterSelectMode
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CanvasTopBar(
                    workspaceName: workspace.name,
                    selectedCount: selectedIDs.count,
                    mode: mode,
                    onToggleSidebar: onToggleSidebar,
                    onExitSelectMode: { mode = .pan },
                    onDeleteSelected: deleteSelected,
                    onCopySelected: copySelected
                )
                .ignoresSafeArea(edges: .top)

                Spacer()

                CanvasToolbar(mode: $mode, onPaste: paste)
                    .ignoresSafeArea(edges: .bottom)
            }

            // Feedback pill sits below the top bar
            if let feedback {
                VStack {
                    Spacer().frame(height: 70)
                    FeedbackBanner(message: feedback)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: feedback != nil)
        .task(id: workspace.id) { await watchClipboard() }
    }

    // MARK: - Clipboard

    private func paste() {
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        let clip = Clip.make(from: content, origin: .clipboard)
        context.insert(clip)
        workspace.place(clip: clip)
        lastClipboardFingerprint = content.fingerprint
        showFeedback("Pasted")
    }

    private func copyToClipboard(_ clip: Clip) {
        ClipboardService.write(clip: clip)
        showFeedback("Copied")
    }

    private func watchClipboard() async {
        lastClipboardFingerprint = ClipboardService.readContent()?.fingerprint
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard let content = ClipboardService.readContent() else { continue }
            guard content.fingerprint != lastClipboardFingerprint else { continue }
            lastClipboardFingerprint = content.fingerprint
            let clip = Clip.make(from: content, origin: .clipboard)
            context.insert(clip)
            workspace.place(clip: clip)
            showFeedback("Captured from clipboard")
        }
    }

    // MARK: - Selection

    private func enterSelectMode(_ placementID: UUID) {
        mode = .select
        selectedIDs = [placementID]
    }

    private func deleteSelected() {
        let toDelete = workspace.placements.filter { selectedIDs.contains($0.id) }
        toDelete.forEach { context.delete($0) }
        workspace.updatedAt = Date()
        selectedIDs.removeAll()
        mode = .pan
        showFeedback(toDelete.count == 1 ? "Deleted 1 card" : "Deleted \(toDelete.count) cards")
    }

    private func copySelected() {
        let texts = workspace.placements
            .filter { selectedIDs.contains($0.id) }
            .compactMap { $0.clip?.content }
            .filter { !$0.isEmpty }
        guard !texts.isEmpty else { return }
        UIPasteboard.general.string = texts.joined(separator: "\n\n")
        showFeedback(texts.count == 1 ? "Copied 1 clip" : "Copied \(texts.count) clips")
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
