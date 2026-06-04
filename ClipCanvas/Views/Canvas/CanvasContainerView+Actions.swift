import SwiftUI
import SwiftData

extension CanvasContainerView {

    // MARK: - Workspace / Selection

    func clearAll() {
        let objects = Array(workspace.canvasObjects)
        let placements = Array(workspace.placements)
        objects.forEach { context.delete($0) }
        placements.forEach { context.delete($0) }
        workspace.updatedAt = Date()
        selectedObjectIDs.removeAll()
        showFeedback(objects.count + placements.count == 0 ? "Canvas is already empty" : "Canvas cleared")
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
        let sourcePlacementIDs = Set(selected.compactMap(\.sourcePlacementID))
        let legacyPlacements = workspace.placements.filter { sourcePlacementIDs.contains($0.id) }
        selected.forEach { context.delete($0) }
        legacyPlacements.forEach { context.delete($0) }
        selectedObjectIDs.removeAll()
        showFeedback(selected.count == 1 ? "Deleted 1 card" : "Deleted \(selected.count) cards")
    }

    func createNoteAtViewCenter() {
        let note = workspace.createNote(centeredAt: visibleViewportCenter, size: CanvasPlacementSizing.defaultSize)
        context.insert(note)
        selectedObjectIDs = [note.id]
        editingObjectID = note.id
        showFeedback("New note")
    }

    func insertImageFromLibrary() {
        showFeedback("Image picker coming soon")
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
            searchFocused = true
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
        showFeedback(objects.count == 1 ? "Attached 1 card" : "Attached \(objects.count) cards")
    }

    func openRecentOrNewAIChat() {
        let recent = workspace.chats
            .filter { !$0.messages.isEmpty }
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
        if object.kind == .stickyNote || object.kind == .clipNote { return .text }
        return .mixed
    }

    // MARK: - Feedback

    func showFeedback(_ msg: String) {
        let token = UUID()
        feedbackToken = token
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            await MainActor.run {
                guard feedbackToken == token else { return }
                withAnimation(.easeInOut(duration: 0.18)) { feedback = nil }
            }
        }
    }
}
