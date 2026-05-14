import PencilKit
import SwiftUI
import SwiftData

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @State private var mode: CanvasMode = .pan
    @State private var feedback: String?
    @State private var feedbackToken = UUID()
    @State private var zoomCommand: ZoomCommand?
    @State private var visibleScale: CGFloat = 1
    @State private var visibleViewportCenter: CGPoint = .zero
    @State private var selectedObjectIDs: Set<UUID> = []
    @State private var visibleObjectIDs: Set<UUID> = []
    @State private var editingObjectID: UUID?
    @State private var noteTextCommand: NoteTextCommand?
    @State private var detailClip: Clip?
    @State private var activeAIChat: AIChat?
    @State private var tagEditSelection: ClipTagEditSelection?
    @State private var colorEditSelection: CanvasObjectColorSelection?
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var activeDrawing: PKDrawing = PKDrawing()
    @State private var activeDrawTool: CanvasDrawTool = .pen
    @State private var drawToolSettings: CanvasDrawTool?
    @State private var penColor: PlatformColor = .label
    @State private var penWidth: CGFloat = 3
    @State private var highlighterColor: PlatformColor = .systemYellow.withAlphaComponent(0.5)
    @State private var highlighterWidth: CGFloat = 20
    @State private var eraserWidth: CGFloat = 34
    @State private var clipboardWatcherTask: Task<Void, Never>?
    @State private var lastClipboardFingerprint: String?
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
                noteTextCommand: $noteTextCommand,
                drawingTool: pencilTool
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CanvasTopBar(
                    workspaceName: workspace.name,
                    workspaces: workspaces,
                    activeWorkspaceID: workspace.id,
                    isRenaming: $isRenaming,
                    renameText: $renameText,
                    renameFocused: $renameFocused,
                    onToggleSidebar: toggleSidebar,
                    onBeginRename: beginRename,
                    onCommitRename: commitRename,
                    onSelectWorkspace: { WorkspaceActionService.activate($0, among: workspaces) },
                    selectedCount: selectedObjectIDs.count,
                    visibleCount: visibleObjectIDs.count,
                    onAskAI: askAIAboutCurrentContext,
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
                    onCreateNote: createNoteAtViewCenter,
                    onAskAI: askAIAboutCurrentContext,
                    onTransform: applyTransformToSelection,
                    onDetails: showSelectedDetails,
                    onEditContent: editSelectedContent,
                    onManageTags: showSelectedTags,
                    onArrangeSelection: { zoomCommand = .arrangeSelection },
                    onColor: showSelectedColors,
                    onFormatBold: { noteTextCommand = NoteTextCommand(kind: .bold) },
                    onFormatBullet: { noteTextCommand = NoteTextCommand(kind: .bullet) },
                    onFormatHighlight: { noteTextCommand = NoteTextCommand(kind: .highlight) },
                    onDone: exitEditing,
                    onDelete: deleteSelected,
                    activeDrawTool: activeDrawTool,
                    onCloseMode: closeToolbarMode,
                    onDrawTool: selectDrawTool,
                    onDrawToolSettings: toggleDrawToolSettings
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)

            if let tool = drawToolSettings {
                CanvasDrawToolSettingsPanel(
                    tool: tool,
                    color: drawColor(for: tool),
                    width: drawWidth(for: tool),
                    onChangeColor: { setDrawColor($0, for: tool) },
                    onChangeWidth: { setDrawWidth($0, for: tool) },
                    onDismiss: { drawToolSettings = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(7)
            }

            if let selection = tagEditSelection {
                CanvasTagPanel(
                    clips: selection.clips,
                    onDismiss: { tagEditSelection = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(8)
            }

            if let selection = colorEditSelection {
                CanvasColorPanel(
                    objects: selection.objects,
                    onDismiss: { colorEditSelection = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(9)
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
        .onAppear {
            context.undoManager = undoManager
            startClipboardListening()
        }
        .onDisappear {
            stopClipboardListening()
        }
        .onChange(of: mode) { _, newMode in
            if newMode != .edit { editingObjectID = nil }
            if newMode != .draw { drawToolSettings = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startClipboardListening()
            } else {
                stopClipboardListening()
            }
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
    }

    private var pencilTool: PKTool {
        switch activeDrawTool {
        case .pen:
            return PKInkingTool(.pen, color: penColor, width: penWidth)
        case .highlighter:
            return PKInkingTool(.marker, color: highlighterColor, width: highlighterWidth)
        case .eraser:
            return PKEraserTool(.fixedWidthBitmap, width: eraserWidth)
        case .lasso:
            return PKLassoTool()
        }
    }

    private func leaveMode() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            mode = .pan
            editingObjectID = nil
            drawToolSettings = nil
        }
    }

    private func closeToolbarMode() {
        if editingObjectID == nil {
            leaveMode()
        } else {
            exitEditing()
        }
    }

    private func selectDrawTool(_ tool: CanvasDrawTool) {
        activeDrawTool = tool
        if drawToolSettings != nil {
            drawToolSettings = tool.supportsSettings ? tool : nil
        }
    }

    private func toggleDrawToolSettings(_ tool: CanvasDrawTool) {
        drawToolSettings = drawToolSettings == tool ? nil : tool
    }

    private func drawColor(for tool: CanvasDrawTool) -> PlatformColor? {
        switch tool {
        case .pen:
            return penColor
        case .highlighter:
            return highlighterColor
        case .eraser, .lasso:
            return nil
        }
    }

    private func drawWidth(for tool: CanvasDrawTool) -> CGFloat {
        switch tool {
        case .pen:
            return penWidth
        case .highlighter:
            return highlighterWidth
        case .eraser:
            return eraserWidth
        case .lasso:
            return 0
        }
    }

    private func setDrawColor(_ color: PlatformColor, for tool: CanvasDrawTool) {
        switch tool {
        case .pen:
            penColor = color
        case .highlighter:
            highlighterColor = color.withAlphaComponent(0.5)
        case .eraser, .lasso:
            break
        }
    }

    private func setDrawWidth(_ width: CGFloat, for tool: CanvasDrawTool) {
        switch tool {
        case .pen:
            penWidth = width
        case .highlighter:
            highlighterWidth = width
        case .eraser:
            eraserWidth = width
        case .lasso:
            break
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
        workspace.place(clip: clip, at: workspace.nextPosition(around: visibleViewportCenter))
        showFeedback("Pasted")
    }

    private func startClipboardListening() {
        guard clipboardWatcherTask == nil else { return }
        lastClipboardFingerprint = ClipboardService.readContent()?.fingerprint
        clipboardWatcherTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0))
                guard !Task.isCancelled, let content = ClipboardService.readContent() else { continue }
                guard content.fingerprint != lastClipboardFingerprint else { continue }
                lastClipboardFingerprint = content.fingerprint
                guard !ClipboardService.wasRecentlyImported(content) else { continue }
                captureClipboardContent(content)
            }
        }
    }

    private func stopClipboardListening() {
        clipboardWatcherTask?.cancel()
        clipboardWatcherTask = nil
    }

    private func captureClipboardContent(_ content: ClipboardContent) {
        let (clip, isNew) = Clip.findOrMake(from: content, origin: .clipboard, in: context)
        if isNew { context.insert(clip) }
        showFeedback(isNew ? "Captured from clipboard" : "Clipboard already saved")
    }

    // MARK: - Rename

    private func beginRename() {
        renameText = WorkspaceNamePolicy.limitedEditingText(workspace.name)
        isRenaming = true
        renameFocused = true
    }

    private func commitRename() {
        WorkspaceActionService.rename(workspace, to: renameText)
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

    private func showSelectedDetails() {
        detailClip = selectedClips.first
    }

    private func showSelectedTags() {
        let clips = selectedClips
        guard !clips.isEmpty else { return }
        if tagEditSelection != nil {
            tagEditSelection = nil
            return
        }
        colorEditSelection = nil
        tagEditSelection = ClipTagEditSelection(clips: clips)
    }

    private func showSelectedColors() {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
            .filter { $0.kind != .image && $0.kind != .drawing && $0.kind != .group && $0.kind != .connector }
        if colorEditSelection != nil {
            colorEditSelection = nil
            return
        }
        guard !objects.isEmpty else {
            showFeedback("Select a note to color")
            return
        }
        tagEditSelection = nil
        colorEditSelection = CanvasObjectColorSelection(objects: objects)
    }

    private func editSelectedContent() {
        guard selectedObjectIDs.count == 1, let id = selectedObjectIDs.first else { return }
        editingObjectID = id
    }

    private func applyTransformToSelection(_ skillID: String) {
        let targets = orderedCanvasObjects(matching: selectedObjectIDs)
            .filter { $0.kind == .stickyNote || $0.kind == .clipNote }
        guard !targets.isEmpty else {
            showFeedback("Select text notes")
            return
        }

        Task {
            await applyTransform(skillID, to: targets.map(\.id))
        }
    }

    @MainActor
    private func applyTransform(_ skillID: String, to objectIDs: [UUID]) async {
        let registry = TransformSkillRegistry()
        var changedCount = 0

        for objectID in objectIDs {
            guard let object = workspace.canvasObjects.first(where: { $0.id == objectID && $0.isVisible }) else {
                continue
            }
            let input = TransformSkillInput(
                workspaceID: workspace.id,
                objectIDs: [object.id],
                clipIDs: object.clip.map { [$0.id] } ?? [],
                text: object.displayText
            )
            guard let result = try? await registry.run(skillID, input: input),
                  let transformed = result.text else {
                continue
            }

            let didChange: Bool
            if let clip = object.clip {
                didChange = performWorkspaceAction(
                    .clipUpdateContent,
                    arguments: WorkspaceClipUpdateContentArguments(clipID: clip.id, content: transformed)
                )
            } else {
                didChange = performWorkspaceAction(
                    .canvasUpdateObjectText,
                    arguments: WorkspaceUpdateObjectTextArguments(objectID: object.id, text: transformed)
                )
            }

            if didChange { changedCount += 1 }
        }

        showFeedback(changedCount == 1 ? "Transformed 1 note" : "Transformed \(changedCount) notes")
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

    private func createNoteAtViewCenter() {
        let note = workspace.createNote(centeredAt: visibleViewportCenter, size: CanvasPlacementSizing.defaultSize)
        context.insert(note)
        selectedObjectIDs = [note.id]
        editingObjectID = note.id
        showFeedback("New note")
    }

    private func askAIAboutCurrentContext() {
        if selectedObjectIDs.isEmpty {
            askAIAboutVisibleCards()
        } else {
            askAIAboutSelection()
        }
    }

    private func askAIAboutSelection() {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        openAIChat(attaching: objects)
    }

    private func askAIAboutVisibleCards() {
        openAIChat(attaching: orderedCanvasObjects(matching: visibleObjectIDs))
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

    private func performWorkspaceAction<T: Encodable>(
        _ name: WorkspaceActionName,
        arguments: T
    ) -> Bool {
        guard let argumentsData = try? JSONEncoder().encode(arguments) else { return false }
        let request = WorkspaceActionRequest(
            name: name,
            workspaceID: workspace.id,
            argumentsData: argumentsData,
            source: .user
        )
        return WorkspaceActionRegistry.perform(request, in: context).success
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

private struct CanvasObjectColorSelection: Identifiable {
    let id = UUID()
    let objects: [CanvasObject]
}
