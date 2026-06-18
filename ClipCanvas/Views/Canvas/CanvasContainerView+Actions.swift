import SwiftUI
import SwiftData
import PhotosUI

extension CanvasContainerView {

    // MARK: - Workspace / Selection

    func clearAll() {
        let objects = Array(workspace.canvasObjects)
        objects.forEach { context.delete($0) }
        workspace.updatedAt = Date()
        selectedObjectIDs.removeAll()
        showFeedback(objects.isEmpty ? "Canvas is already empty" : "Canvas cleared")
    }

    func showSelectedDetails() {
        detailClip = selectedClips.first
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
        guard !objects.isEmpty else { showFeedback("Select a note to color"); return }
        tagClips = nil
        colorObjects = objects
    }

    func editSelectedContent() {
        guard selectedObjectIDs.count == 1, let id = selectedObjectIDs.first else { return }
        editingObjectID = id
    }

    func exitEditing() { editingObjectID = nil }

    func deleteSelected() {
        let selected = workspace.canvasObjects.filter { selectedObjectIDs.contains($0.id) }
        selected.forEach { context.delete($0) }
        selectedObjectIDs.removeAll()
        showFeedback(selected.count == 1 ? "Deleted 1 card" : "Deleted \(selected.count) cards")
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
            showFeedback("Could not duplicate selection")
            return
        }
        let request = WorkspaceActionRequest(
            name: .canvasDuplicateObjects,
            workspaceID: workspace.id,
            argumentsData: data,
            source: .user
        )
        let result = WorkspaceActionRegistry.perform(request, in: context, confirmed: true)
        if result.success {
            selectedObjectIDs = Set(result.changedObjectIDs)
            showFeedback(result.changedObjectIDs.count == 1 ? "Duplicated 1 card" : "Duplicated \(result.changedObjectIDs.count) cards")
        } else {
            showFeedback(result.message)
        }
    }

    func createNoteAtViewCenter() {
        let note = workspace.createNote(centeredAt: visibleViewportCenter, size: CanvasPlacementSizing.defaultSize)
        selectedObjectIDs = [note.id]
        editingObjectID = note.id
        showFeedback("New note")
    }

    func createTextAtViewCenter() {
        let object = workspace.createText(centeredAt: visibleViewportCenter)
        selectedObjectIDs = [object.id]
        editingObjectID = object.id
        showFeedback("New text")
    }

    func insertImageFromLibrary() {
        isImagePickerPresented = true
    }

    func importSelectedImage(_ item: PhotosPickerItem?) async {
        defer { selectedPhotoItem = nil }
        guard let item else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                showFeedback("Could not load image")
                return
            }
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
            showFeedback("Image added")
        } catch {
            showFeedback("Could not load image")
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

    func openAIChat(attaching objects: [CanvasObject]) {
        guard !objects.isEmpty else { showFeedback("No cards to attach"); return }
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
        workspace.canvasObjects.filter { selectedObjectIDs.contains($0.id) }.compactMap(\.clip)
    }

    func orderedCanvasObjects(matching ids: Set<UUID>) -> [CanvasObject] {
        workspace.canvasObjects
            .filter { ids.contains($0.id) && $0.isVisible }
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

    func showFeedback(_ msg: String) {
        feedbackPresenter.show(msg)
    }
}
