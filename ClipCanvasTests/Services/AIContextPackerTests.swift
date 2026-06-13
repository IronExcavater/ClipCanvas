import Foundation
import Testing
@testable import ClipCanvas

@Suite struct AIContextPackerTests {
    @Test func attachmentsArePackedBeforeSelectedAndVisibleObjects() {
        let workspace = Workspace(name: "Research")
        let attachedClip = Clip(content: "Attached source", origin: .clipboard)
        let selectedClip = Clip(content: "Selected card", origin: .clipboard)
        let visibleClip = Clip(content: "Visible card", origin: .clipboard)
        let attachedMessage = ChatMessage(role: .user, content: "Use this")
        attachedMessage.attachments = [ChatAttachment(clip: attachedClip)]
        let chat = AIChat(title: "Chat")
        chat.messages = [attachedMessage]

        let selected = CanvasObject(kind: .clipNote, workspace: workspace, clip: selectedClip, x: 0, y: 0, width: 220, height: 140)
        let visible = CanvasObject(kind: .clipNote, workspace: workspace, clip: visibleClip, x: 260, y: 0, width: 220, height: 140)
        workspace.canvasObjects = [selected, visible]

        let snapshot = AIContextPacker.pack(
            chat: chat,
            workspace: workspace,
            mode: .thinking,
            selectedObjectIDs: [selected.id],
            visibleObjectIDs: [selected.id, visible.id],
            recentClips: []
        )

        #expect(snapshot.items.map(\.source) == [.attachment, .selectedObject, .visibleObject])
        #expect(snapshot.items.map(\.content) == ["Attached source", "Selected card", "Visible card"])
    }

    @Test func attachedCanvasObjectsArePackedAsObjects() {
        let workspace = Workspace(name: "Research")
        let stickyObject = CanvasObject(kind: .stickyNote, workspace: workspace, x: 0, y: 0, width: 220, height: 140, text: "Sticky idea")
        workspace.canvasObjects = [stickyObject]
        let message = ChatMessage(role: .user, content: "Use this note")
        message.attachments = [ChatAttachment(object: stickyObject)]
        let chat = AIChat(title: "Chat")
        chat.messages = [message]

        let snapshot = AIContextPacker.pack(
            chat: chat,
            workspace: workspace,
            mode: .quick,
            selectedObjectIDs: [],
            visibleObjectIDs: [],
            recentClips: []
        )

        #expect(snapshot.items.count == 1)
        #expect(snapshot.items.first?.source == .attachment)
        #expect(snapshot.items.first?.objectID == stickyObject.id)
        #expect(snapshot.items.first?.content == "Sticky idea")
    }

    @Test func deletedAttachedCanvasObjectsAreOmitted() {
        let workspace = Workspace(name: "Research")
        let clip = Clip(content: "Source should not leak", origin: .clipboard)
        let object = CanvasObject(kind: .clipNote, workspace: workspace, clip: clip, x: 0, y: 0, width: 220, height: 140)
        object.softDelete()
        workspace.canvasObjects = [object]
        let message = ChatMessage(role: .user, content: "Use this note")
        message.attachments = [ChatAttachment(object: object)]
        let chat = AIChat(title: "Chat")
        chat.messages = [message]

        let snapshot = AIContextPacker.pack(
            chat: chat,
            workspace: workspace,
            mode: .quick,
            selectedObjectIDs: [],
            visibleObjectIDs: [],
            recentClips: []
        )

        #expect(snapshot.items.isEmpty)
    }

    @Test func quickModeLimitsObjectsMoreAggressivelyThanThinkingMode() {
        let workspace = Workspace(name: "Big")
        let objects = (0..<40).map { index in
            CanvasObject(kind: .stickyNote, workspace: workspace, x: Double(index * 10), y: 0, width: 220, height: 140, text: "Note \(index)")
        }
        workspace.canvasObjects = objects
        let visibleIDs = Set(objects.map(\.id))

        let quick = AIContextPacker.pack(
            chat: AIChat(title: "Quick"),
            workspace: workspace,
            mode: .quick,
            selectedObjectIDs: [],
            visibleObjectIDs: visibleIDs,
            recentClips: []
        )
        let thinking = AIContextPacker.pack(
            chat: AIChat(title: "Thinking"),
            workspace: workspace,
            mode: .thinking,
            selectedObjectIDs: [],
            visibleObjectIDs: visibleIDs,
            recentClips: []
        )

        #expect(quick.items.count == AIModelPresetService.preset(for: .quick).maxContextObjects)
        #expect(thinking.items.count == AIModelPresetService.preset(for: .thinking).maxContextObjects)
        #expect(thinking.items.count > quick.items.count)
    }

    @Test func privateClipContentIsExcludedByDefault() {
        let workspace = Workspace(name: "Secrets")
        let privateClip = Clip(content: "password: hunter2", origin: .clipboard, sensitivity: .privateContent)
        let object = CanvasObject(kind: .clipNote, workspace: workspace, clip: privateClip, x: 0, y: 0, width: 220, height: 140)
        workspace.canvasObjects = [object]

        let snapshot = AIContextPacker.pack(
            chat: AIChat(title: "Safe"),
            workspace: workspace,
            mode: .thinking,
            selectedObjectIDs: [object.id],
            visibleObjectIDs: [object.id],
            recentClips: [privateClip]
        )

        #expect(snapshot.items.allSatisfy { $0.content != "password: hunter2" })
        #expect(snapshot.items.contains { $0.isPrivate && $0.content == nil })
        #expect(snapshot.privateOmittedCount == 1)
    }

    @Test func workspaceSummaryCountsVisibleSelectedAndPrivateObjects() {
        let workspace = Workspace(name: "Summary")
        let publicClip = Clip(content: "Public", origin: .clipboard)
        let privateClip = Clip(content: "secret", origin: .clipboard, sensitivity: .privateContent)
        let publicObject = CanvasObject(kind: .clipNote, workspace: workspace, clip: publicClip, x: 0, y: 0, width: 220, height: 140)
        let privateObject = CanvasObject(kind: .clipNote, workspace: workspace, clip: privateClip, x: 250, y: 0, width: 220, height: 140)
        workspace.canvasObjects = [publicObject, privateObject]

        let snapshot = AIContextPacker.pack(
            chat: AIChat(title: "Summary"),
            workspace: workspace,
            mode: .thinking,
            selectedObjectIDs: [publicObject.id],
            visibleObjectIDs: [publicObject.id, privateObject.id],
            recentClips: []
        )

        #expect(snapshot.workspace.name == "Summary")
        #expect(snapshot.workspace.totalObjectCount == 2)
        #expect(snapshot.workspace.visibleObjectCount == 2)
        #expect(snapshot.workspace.selectedObjectCount == 1)
        #expect(snapshot.workspace.privateObjectCount == 1)
    }
}
