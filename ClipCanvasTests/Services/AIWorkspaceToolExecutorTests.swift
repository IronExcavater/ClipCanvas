import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct AIWorkspaceToolExecutorTests {
    @Test func successfulToolCallCreatesCompletedEvent() throws {
        let (context, workspace, message) = try makeWorkspaceAndMessage()
        let call = try AIWorkspaceToolCall(
            toolName: "canvas_create_sticky_note",
            workspaceID: workspace.id,
            arguments: WorkspaceCreateStickyNoteArguments(
                text: "AI note",
                x: 20,
                y: 30,
                width: 220,
                height: 150,
                style: .default
            )
        )

        let result = AIWorkspaceToolExecutor.execute(call, message: message, in: context)

        #expect(result.success)
        #expect(result.changedObjectIDs.count == 1)
        let event = try #require(message.toolEvents.first)
        #expect(event.status == .completed)
        #expect(event.summary == "Created sticky note")
        #expect(event.completedAt != nil)
        #expect((try context.fetch(FetchDescriptor<CanvasObject>())).count == 1)
    }

    @Test func destructiveToolCallRequiresConfirmationBeforeMutating() throws {
        let (context, workspace, message) = try makeWorkspaceAndMessage()
        let object = CanvasObject(kind: .stickyNote, workspace: workspace, x: 0, y: 0, width: 220, height: 150)
        context.insert(object)
        workspace.canvasObjects.append(object)
        let call = try AIWorkspaceToolCall(
            toolName: "canvas_delete_objects",
            workspaceID: workspace.id,
            arguments: WorkspaceObjectIDsArguments(objectIDs: [object.id])
        )

        let result = AIWorkspaceToolExecutor.execute(call, message: message, in: context)

        #expect(!result.success)
        #expect(result.needsConfirmation)
        let event = try #require(message.toolEvents.first)
        #expect(event.status == .needsConfirmation)
        #expect(event.completedAt == nil)
        #expect((try context.fetch(FetchDescriptor<CanvasObject>())).count == 1)
    }

    @Test func workspaceManagementToolIsRejected() throws {
        let (context, workspace, message) = try makeWorkspaceAndMessage()
        let call = try AIWorkspaceToolCall(
            toolName: "workspace_rename",
            workspaceID: workspace.id,
            arguments: EmptyWorkspaceActionArguments()
        )

        let result = AIWorkspaceToolExecutor.execute(call, message: message, in: context)

        #expect(!result.success)
        #expect(result.message == "Workspace management is not available through shared workspace actions.")
        #expect(message.toolEvents.first?.status == .failed)
    }

    @Test func unknownToolCreatesFailedEvent() throws {
        let (context, workspace, message) = try makeWorkspaceAndMessage()
        let call = AIWorkspaceToolCall(
            toolName: "canvas_make_magic",
            workspaceID: workspace.id,
            argumentsData: Data()
        )

        let result = AIWorkspaceToolExecutor.execute(call, message: message, in: context)

        #expect(!result.success)
        #expect(result.message == "Unknown AI tool: canvas_make_magic")
        #expect(message.toolEvents.first?.status == .failed)
        #expect(message.toolEvents.first?.completedAt != nil)
    }

    private func makeWorkspaceAndMessage() throws -> (ModelContext, Workspace, ChatMessage) {
        let context = try ModelContextFactory.makeContext()
        let workspace = Workspace(name: "AI", isActive: true)
        let chat = AIChat(title: "AI Chat")
        let message = ChatMessage(role: .assistant, content: "")
        chat.workspace = workspace
        chat.messages.append(message)
        message.chat = chat
        context.insert(workspace)
        context.insert(chat)
        context.insert(message)
        return (context, workspace, message)
    }
}
