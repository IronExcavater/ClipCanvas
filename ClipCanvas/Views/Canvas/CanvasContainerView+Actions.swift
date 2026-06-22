import SwiftUI
import SwiftData
import PhotosUI
import PencilKit

extension CanvasContainerView {

    // MARK: - Workspace / Selection

    func clearAll() {
        let objects = Array(workspace.canvasObjects)
        guard !objects.isEmpty || !activeDrawing.bounds.isEmpty else {
            showFeedback("Canvas is already empty", kind: .info)
            return
        }
        captureCanvasUndoSnapshot()
        objects.forEach { context.delete($0) }
        activeDrawing = PKDrawing()
        workspace.updatedAt = Date()
        selectedObjectIDs.removeAll()
        showFeedback("Canvas cleared", kind: .success)
    }

    func showSelectedDetails() {
        if let clip = selectedClips.first {
            detailClip = clip
            return
        }
        guard let object = orderedCanvasObjects(matching: selectedObjectIDs).first,
              object.kind == .stickyNote || object.kind == .text else { return }
        captureCanvasUndoSnapshot()
        let clip = Clip(content: object.text, origin: .typed)
        context.insert(clip)
        object.clip = clip
        object.kind = .clipNote
        object.text = ""
        object.markUpdated()
        detailClip = clip
    }

    func showSelectedTags() {
        let clips = selectedClips
        guard !clips.isEmpty else { return }
        if tagClips != nil { tagClips = nil; return }
        colorObjects = nil
        tagClips = clips
    }

    func showSelectedColors() {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
            .filter { $0.kind != .image && $0.kind != .drawing && $0.kind != .group && $0.kind != .connector }
        if colorObjects != nil { colorObjects = nil; return }
        guard !objects.isEmpty else { showFeedback("Select a note to color", kind: .info); return }
        tagClips = nil
        colorObjects = objects
    }

    func editSelectedContent() {
        guard selectedObjectIDs.count == 1,
              let id = selectedObjectIDs.first,
              let object = orderedCanvasObjects(matching: selectedObjectIDs).first,
              canvasSelectionKind(for: object) == .text || canvasSelectionKind(for: object) == .clip else { return }
        editingObjectID = id
    }

    func exitEditing() { editingObjectID = nil }

    func deleteSelected() {
        let selected = workspace.canvasObjects.filter { selectedObjectIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        captureCanvasUndoSnapshot()
        selected.forEach { context.delete($0) }
        selectedObjectIDs.removeAll()
        showFeedback(selected.count == 1 ? "Deleted 1 card" : "Deleted \(selected.count) cards", kind: .success)
    }

    func duplicateSelected() {
        let ids = Array(selectedObjectIDs)
        guard !ids.isEmpty else { return }
        let arguments = WorkspaceDuplicateObjectsArguments(
            objectIDs: ids,
            offsetX: 28,
            offsetY: 28
        )
        guard let data = try? JSONEncoder().encode(arguments) else {
            showFeedback("Could not duplicate selection", kind: .failure)
            return
        }
        captureCanvasUndoSnapshot()
        let request = WorkspaceActionRequest(
            name: .canvasDuplicateObjects,
            workspaceID: workspace.id,
            argumentsData: data,
            source: .user
        )
        let result = WorkspaceActionRegistry.perform(request, in: context, confirmed: true)
        if result.success {
            selectedObjectIDs = Set(result.changedObjectIDs)
            showFeedback(result.changedObjectIDs.count == 1 ? "Duplicated 1 card" : "Duplicated \(result.changedObjectIDs.count) cards", kind: .success)
        } else {
            showFeedback(result.message, kind: .failure)
        }
    }

    func createNoteAtViewCenter() {
        captureCanvasUndoSnapshot()
        let note = workspace.createNote(centeredAt: visibleViewportCenter, size: CanvasPlacementSizing.defaultSize)
        selectedObjectIDs = [note.id]
        editingObjectID = note.id
        showFeedback("New note", kind: .success)
    }

    func insertImageFromLibrary() {
        isImagePickerPresented = true
    }

    func loadPersistedDrawing() {
        isLoadingPersistedDrawing = true
        activeDrawing = CanvasDrawingPersistence.drawing(in: workspace)
        DispatchQueue.main.async {
            isLoadingPersistedDrawing = false
        }
    }

    func persistActiveDrawing(_ drawing: PKDrawing) {
        guard !isLoadingPersistedDrawing else { return }
        CanvasDrawingPersistence.persist(drawing, in: workspace, context: context)
    }

    func importSelectedImage(_ item: PhotosPickerItem?) async {
        defer { selectedPhotoItem = nil }
        guard let item else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                showFeedback("Could not load image", kind: .failure)
                return
            }
            captureCanvasUndoSnapshot()
            let clip = Clip(content: "Image", imageData: data, imageUTI: item.supportedContentTypes.first?.identifier, origin: .typed)
            context.insert(clip)
            let object = workspace.place(
                clip: clip,
                at: CGPoint(
                    x: visibleViewportCenter.x - 130,
                    y: visibleViewportCenter.y - 95
                )
            )
            selectedObjectIDs = [object.id]
            showFeedback("Image added", kind: .success)
        } catch {
            showFeedback("Could not load image", kind: .failure)
        }
    }

    // MARK: - Rename / Search / Sidebar

    func beginRename() {
        renameText = WorkspaceNamePolicy.limitedEditingText(workspace.name)
        isRenaming = true
        renameFocused = true
    }

    func commitRename() {
        WorkspaceActionService.rename(workspace, to: renameText)
        isRenaming = false
        renameFocused = false
    }

    func toggleSidebar() {
        if isRenaming { commitRename() }
        onToggleSidebar()
    }

    func toggleCanvasSearch() {
        if isCanvasSearchActive {
            closeCanvasSearch()
        } else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) { isCanvasSearchActive = true }
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    func closeCanvasSearch() {
        searchFocused = false
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            canvasSearch = ""
            isCanvasSearchActive = false
        }
    }

    // MARK: - AI

    func askAIAboutCurrentContext() {
        if selectedObjectIDs.isEmpty { askAIAboutVisibleCards() } else { askAIAboutSelection() }
    }

    func askAIAboutSelection() {
        openAIChat(attaching: orderedCanvasObjects(matching: selectedObjectIDs))
    }

    func askAIAboutVisibleCards() {
        openAIChat(attaching: orderedCanvasObjects(matching: visibleObjectIDs))
    }

    func runAIAction(_ skill: AITransformSkill, on objects: [CanvasObject]) {
        captureCanvasUndoSnapshot()
        let result = AITransformActionService.apply(
            skill,
            to: objects,
            workspace: workspace,
            in: context,
            source: .user
        )
        if result.success {
            selectedObjectIDs = result.changedObjectIDs.isEmpty
                ? Set(objects.map(\.id))
                : Set(result.changedObjectIDs)
            showFeedback(skill.completion(for: result), kind: .success)
        } else {
            _ = undoStack.popLast()
            showFeedback(result.message, kind: .failure)
        }
    }

    func runAIActionOnSelection(_ skill: AITransformSkill) {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        guard !objects.isEmpty else {
            showFeedback("Select cards first", kind: .info)
            return
        }
        guard let preview = AISelectionSkillPreview(skill: skill, objects: objects) else {
            showFeedback("Select a text card first", kind: .info)
            return
        }
        aiSkillPreview = preview
    }

    func openAIChat(attaching objects: [CanvasObject]) {
        guard !objects.isEmpty else { showFeedback("No cards to attach", kind: .info); return }
        let chat = AIChatService.createChat(in: context, workspace: workspace)
        AIChatService.attachObjects(objects, to: chat, in: context)
        activeAIChat = chat
    }

    func openRecentOrNewAIChat() {
        let recent = workspace.chats
            .filter { $0.deletedAt == nil && !$0.messages.isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        activeAIChat = recent ?? AIChatService.createChat(in: context, workspace: workspace)
    }

    // MARK: - Helpers

    var selectedClips: [Clip] {
        workspace.canvasObjects.filter { selectedObjectIDs.contains($0.id) && $0.isCanvasContent }.compactMap(\.clip)
    }

    func orderedCanvasObjects(matching ids: Set<UUID>) -> [CanvasObject] {
        workspace.canvasObjects
            .filter { ids.contains($0.id) && $0.isCanvasContent }
            .sorted { lhs, rhs in
                if lhs.zIndex == rhs.zIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.zIndex < rhs.zIndex
            }
    }

    func canvasSelectionKind(for object: CanvasObject) -> CanvasSelectionKind {
        if object.kind == .image || object.clip?.type == .image { return .image }
        if object.clip != nil { return .clip }
        if object.kind == .stickyNote || object.kind == .text { return .text }
        return .mixed
    }

    // MARK: - Feedback

    func showFeedback(_ msg: String, kind: FeedbackKind? = nil) {
        feedbackPresenter.show(msg, kind: kind)
    }

    // MARK: - Canvas Undo

    func captureCanvasUndoSnapshot() {
        undoStack.append(CanvasUndoSnapshot(workspace: workspace, drawingData: activeDrawing.dataRepresentation()))
        if undoStack.count > 40 {
            undoStack.removeFirst(undoStack.count - 40)
        }
        redoStack.removeAll()
    }

    func undoCanvasChange() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(CanvasUndoSnapshot(workspace: workspace, drawingData: activeDrawing.dataRepresentation()))
        restoreCanvas(snapshot)
    }

    func redoCanvasChange() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(CanvasUndoSnapshot(workspace: workspace, drawingData: activeDrawing.dataRepresentation()))
        restoreCanvas(snapshot)
    }

    private func restoreCanvas(_ snapshot: CanvasUndoSnapshot) {
        snapshot.restore(in: workspace, context: context)
        activeDrawing = (try? PKDrawing(data: snapshot.drawingData)) ?? PKDrawing()
        selectedObjectIDs.removeAll()
        editingObjectID = nil
        tagClips = nil
        colorObjects = nil
        detailClip = nil
        showFeedback("Canvas restored", kind: .success)
    }
}

struct AISelectionSkillPreview: Identifiable {
    let id = UUID()
    let skill: AITransformSkill
    let objectIDs: Set<UUID>
    let title: String
    let message: String

    init?(skill: AITransformSkill, objects: [CanvasObject]) {
        let objectIDs = Set(objects.map(\.id))
        let canTransform = objects.contains { object in
            guard object.clip?.type != .image else { return false }
            let source = object.clip?.content ?? object.text
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return TextTransformFallbacks.text(for: skill.id, input: source) != nil
        }
        guard !objectIDs.isEmpty, canTransform else { return nil }
        self.skill = skill
        self.objectIDs = objectIDs
        self.title = objects.count == 1 ? "Change Card?" : "Change Cards?"
        self.message = objects.count == 1
            ? "Are you sure you want to change the card?"
            : "Are you sure you want to change the cards?"
    }
}
