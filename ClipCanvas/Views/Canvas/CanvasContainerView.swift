import PencilKit
import SwiftUI
import SwiftData

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @State private var mode: CanvasMode = .pan
    @State private var feedback: String?
    @State private var feedbackToken = UUID()
    @State private var zoomCommand: ZoomCommand?
    @State private var visibleScale: CGFloat = 1
    @State private var visibleViewportCenter: CGPoint = .zero
    @State private var selectedObjectIDs: Set<UUID> = []
    @State private var visibleObjectIDs: Set<UUID> = []
    @State private var editingObjectID: UUID?
    @State private var detailClip: Clip?
    @State private var activeAIChat: AIChat?
    @State private var tagEditSelection: ClipTagEditSelection?
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var activeDrawing: PKDrawing = PKDrawing()
    @State private var drawingTool: PKTool = PKInkingTool(.pen, color: .label, width: 3)
    @FocusState private var renameFocused: Bool

    var body: some View {
        ZStack {
            CanvasView(
                workspace: workspace,
                mode: mode,
                zoomCommand: $zoomCommand,
                selectedObjectIDs: $selectedObjectIDs,
                editingObjectID: $editingObjectID,
                visibleScale: $visibleScale,
                visibleViewportCenter: $visibleViewportCenter,
                visibleObjectIDs: $visibleObjectIDs,
                activeDrawing: $activeDrawing,
                drawingTool: drawingTool,
                onCreateConnector: createConnector
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
                    selectedCount: selectedObjectIDs.count,
                    visibleCount: visibleObjectIDs.count,
                    onAskAISelection: askAIAboutSelection,
                    onAskAIVisible: askAIAboutVisibleCards,
                    onClearAll: clearAll,
                    onArrangeAll: { zoomCommand = .arrangeAll },
                    onFitContent: { zoomCommand = .fitContent }
                )

                Spacer()

                HStack {
                    CanvasUndoControls(
                        onUndo: { undoManager?.undo() },
                        onRedo: { undoManager?.redo() }
                    )
                    .padding(.leading, 14)
                    .padding(.bottom, 12)
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
                    selectedCount: selectedObjectIDs.count,
                    isEditing: editingObjectID != nil,
                    onPaste: paste,
                    onAskAI: askAIAboutSelection,
                    onDetails: showSelectedDetails,
                    onEditContent: editSelectedContent,
                    onManageTags: showSelectedTags,
                    onArrangeSelection: { zoomCommand = .arrangeSelection },
                    onBullet: {},
                    onColor: {},
                    onDone: exitEditing,
                    onDelete: deleteSelected,
                    onDrawPen: { drawingTool = PKInkingTool(.pen, color: .label, width: 3) },
                    onDrawHighlighter: { drawingTool = PKInkingTool(.marker, color: .systemYellow.withAlphaComponent(0.5), width: 20) },
                    onDrawEraser: { drawingTool = PKEraserTool(.vector) },
                    onDrawLasso: { drawingTool = PKLassoTool() },
                    onDrawConvert: convertDrawing,
                    onDrawSave: saveDrawing,
                    onDrawClear: { activeDrawing = PKDrawing() }
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
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: selectedObjectIDs)
        .onAppear { context.undoManager = undoManager }
        .onChange(of: mode) { _, newMode in
            if newMode != .edit { editingObjectID = nil }
        }
        // Tapping the canvas background deselects everything — also exit inline editing
        // so the keyboard dismisses instead of staying up with no selected card.
        .onChange(of: selectedObjectIDs) { _, newIDs in
            if let editing = editingObjectID, !newIDs.contains(editing) {
                editingObjectID = nil
            }
        }
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
        .sheet(item: $activeAIChat) { chat in
            AIChatDetailSheet(chat: chat)
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
        let objects = Array(workspace.canvasObjects)
        let placements = Array(workspace.placements)
        objects.forEach { context.delete($0) }
        placements.forEach { context.delete($0) }
        workspace.updatedAt = Date()
        selectedObjectIDs.removeAll()
        showFeedback(objects.count + placements.count == 0 ? "Canvas is already empty" : "Canvas cleared")
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

    private func showSelectedTags() {
        let clips = selectedClips
        guard !clips.isEmpty else { return }
        tagEditSelection = ClipTagEditSelection(clips: clips)
    }

    private func editSelectedContent() {
        guard selectedObjectIDs.count == 1, let id = selectedObjectIDs.first else { return }
        editingObjectID = id
    }

    private func exitEditing() {
        editingObjectID = nil
    }

    private func deleteSelected() {
        let selected = workspace.canvasObjects.filter { selectedObjectIDs.contains($0.id) }
        let sourcePlacementIDs = Set(selected.compactMap(\.sourcePlacementID))
        let legacyPlacements = workspace.placements.filter { sourcePlacementIDs.contains($0.id) }
        selected.forEach { context.delete($0) }
        legacyPlacements.forEach { context.delete($0) }
        selectedObjectIDs.removeAll()
        showFeedback(selected.count == 1 ? "Deleted 1 card" : "Deleted \(selected.count) cards")
    }

    private func askAIAboutSelection() {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        openAIChat(attaching: objects)
    }

    private func askAIAboutVisibleCards() {
        let objects = orderedCanvasObjects(matching: visibleObjectIDs)
        openAIChat(attaching: objects)
    }

    private func openAIChat(attaching objects: [CanvasObject]) {
        guard !objects.isEmpty else {
            showFeedback("No cards to attach")
            return
        }

        let chat = AIChatService.createChat(in: context, workspace: workspace)
        AIChatService.attachObjects(objects, to: chat, in: context)
        activeAIChat = chat
        showFeedback(objects.count == 1 ? "Attached 1 card" : "Attached \(objects.count) cards")
    }

    // MARK: - Connectors

    private func createConnector(_ connector: CanvasConnector) {
        let object = CanvasObject(kind: .connector, workspace: workspace,
                                  x: 0, y: 0, width: 0, height: 0,
                                  connector: connector)
        context.insert(object)
    }

    // MARK: - Drawing

    private func saveDrawing() {
        guard !activeDrawing.strokes.isEmpty,
              let data = try? activeDrawing.dataRepresentation() else { return }
        let bounds = activeDrawing.bounds
        let size = CanvasPlacementSizing.softSnapSize(CGSize(
            width: max(bounds.width, CanvasPlacementSizing.defaultSize.width),
            height: max(bounds.height, CanvasPlacementSizing.defaultSize.height)
        ))
        let object = CanvasObject(
            kind: .drawing,
            workspace: workspace,
            x: visibleViewportCenter.x - size.width / 2,
            y: visibleViewportCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        object.drawingData = data
        context.insert(object)
        activeDrawing = PKDrawing()
        showFeedback("Drawing saved")
    }

    private func convertDrawing() {
        guard !activeDrawing.strokes.isEmpty else { return }
        let drawing = activeDrawing
        let bounds = drawing.bounds
        let size = CGSize(width: max(bounds.maxX, 100), height: max(bounds.maxY, 100))
        Task {
            let texts = await DrawingConversionService.recognizeText(in: drawing, size: size)
            await MainActor.run {
                guard !texts.isEmpty else {
                    showFeedback("No text recognized")
                    return
                }
                for (index, text) in texts.enumerated() {
                    let offset = Double(index) * 24
                    let note = CanvasObject(
                        kind: .stickyNote,
                        workspace: workspace,
                        x: visibleViewportCenter.x - 110 + offset,
                        y: visibleViewportCenter.y - 75 + offset,
                        width: CanvasPlacementSizing.defaultSize.width,
                        height: CanvasPlacementSizing.defaultSize.height,
                        text: text
                    )
                    context.insert(note)
                }
                activeDrawing = PKDrawing()
                showFeedback(texts.count == 1 ? "Converted to 1 note" : "Converted to \(texts.count) notes")
            }
        }
    }

    private var selectedClips: [Clip] {
        workspace.canvasObjects
            .filter { selectedObjectIDs.contains($0.id) }
            .compactMap(\.clip)
    }

    private func orderedCanvasObjects(matching ids: Set<UUID>) -> [CanvasObject] {
        workspace.canvasObjects
            .filter { ids.contains($0.id) && $0.isVisible }
            .sorted { lhs, rhs in
                if lhs.zIndex == rhs.zIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.zIndex < rhs.zIndex
            }
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
