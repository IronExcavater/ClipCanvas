import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct WorkspaceActionRegistryTests {
    @Test func validatesInitialSharedActionNames() {
        let names: [WorkspaceActionName] = [
            .canvasCreateStickyNote,
            .canvasCreateClipNote,
            .canvasUpdateObjectText,
            .canvasMoveObjects,
            .canvasResizeObjects,
            .canvasDeleteObjects,
            .canvasDuplicateObjects,
            .canvasCreateConnector,
            .canvasUpdateConnector,
            .canvasGroupObjects,
            .canvasUngroupObjects,
            .canvasArrangeGrid,
            .canvasFitViewToContent,
            .clipApplyTransform,
            .clipUpdateContent,
            .clipAddTags,
            .clipRemoveTags,
            .chatAttachObjects,
        ]

        for name in names {
            let validation = WorkspaceActionPermissionService.validate(name: name, source: .ai)
            #expect(validation.isAllowed)
        }
    }

    @Test func rejectsWorkspaceManagementActionsForAutomationSources() {
        let workspaceActions: [WorkspaceActionName] = [
            .workspaceCreate,
            .workspaceDelete,
            .workspaceRename,
            .workspaceActivate,
        ]
        let automationSources: [WorkspaceActionSource] = [.ai, .appIntent, .mcp]

        for source in automationSources {
            for name in workspaceActions {
                let validation = WorkspaceActionPermissionService.validate(name: name, source: source)
                #expect(!validation.isAllowed)
            }
        }
    }

    @Test func createsStickyNoteObject() throws {
        let (context, workspace) = try makeWorkspace()
        let request = try request(
            .canvasCreateStickyNote,
            workspace: workspace,
            arguments: WorkspaceCreateStickyNoteArguments(
                text: "Plan the action layer",
                x: 20,
                y: 40,
                width: 260,
                height: 160,
                style: CanvasObjectStyle(fillHex: "#FFE6A7", strokeHex: nil, textHex: "#111111", lineWidth: 0, fontSize: 16)
            )
        )

        let result = WorkspaceActionRegistry.perform(request, in: context)

        #expect(result.success)
        #expect(result.changedObjectIDs.count == 1)
        let objects = try context.fetch(FetchDescriptor<CanvasObject>())
        #expect(objects.count == 1)
        #expect(objects[0].text == "Plan the action layer")
        #expect(objects[0].frame == CGRect(x: 20, y: 40, width: 260, height: 160))
    }

    @Test func updatesMovesAndResizesObjects() throws {
        let (context, workspace) = try makeWorkspace()
        let object = makeObject(in: workspace, context: context)

        let update = try request(
            .canvasUpdateObjectText,
            workspace: workspace,
            arguments: WorkspaceUpdateObjectTextArguments(objectID: object.id, text: "Updated")
        )
        let move = try request(
            .canvasMoveObjects,
            workspace: workspace,
            arguments: WorkspaceMoveObjectsArguments(objectIDs: [object.id], deltaX: 15, deltaY: -5)
        )
        let resize = try request(
            .canvasResizeObjects,
            workspace: workspace,
            arguments: WorkspaceResizeObjectsArguments(
                sizes: [WorkspaceObjectSize(objectID: object.id, width: 320, height: 200)]
            )
        )

        #expect(WorkspaceActionRegistry.perform(update, in: context).success)
        #expect(WorkspaceActionRegistry.perform(move, in: context).success)
        #expect(WorkspaceActionRegistry.perform(resize, in: context).success)
        #expect(object.text == "Updated")
        #expect(object.frame == CGRect(x: 15, y: -5, width: 320, height: 200))
    }

    @Test func duplicatesObjectsWithoutCopyingClipContent() throws {
        let (context, workspace) = try makeWorkspace()
        let clip = Clip(content: "Clip source", origin: .clipboard)
        context.insert(clip)
        let object = CanvasObject(kind: .clipNote, workspace: workspace, clip: clip, x: 10, y: 20, width: 220, height: 140)
        context.insert(object)
        workspace.canvasObjects.append(object)

        let duplicate = try request(
            .canvasDuplicateObjects,
            workspace: workspace,
            arguments: WorkspaceDuplicateObjectsArguments(objectIDs: [object.id], offsetX: 24, offsetY: 24)
        )

        let result = WorkspaceActionRegistry.perform(duplicate, in: context)

        #expect(result.success)
        let objects = try context.fetch(FetchDescriptor<CanvasObject>())
        #expect(objects.count == 2)
        let copy = try #require(objects.first { $0.id != object.id })
        #expect(copy.clip?.id == clip.id)
        #expect(copy.text.isEmpty)
        #expect(copy.frame.origin == CGPoint(x: 34, y: 44))
    }

    @Test func arrangesObjectsByTopLeftGridAndReturnsFitViewResult() throws {
        let (context, workspace) = try makeWorkspace()
        let first = makeObject(in: workspace, context: context, x: 200, y: 200, width: 100, height: 80)
        let second = makeObject(in: workspace, context: context, x: 400, y: 400, width: 120, height: 60)
        let third = makeObject(in: workspace, context: context, x: 600, y: 600, width: 90, height: 90)

        let arrange = try request(
            .canvasArrangeGrid,
            workspace: workspace,
            arguments: WorkspaceArrangeGridArguments(
                objectIDs: [first.id, second.id, third.id],
                originX: 10,
                originY: 20,
                columnCount: 2,
                horizontalSpacing: 12,
                verticalSpacing: 14
            )
        )
        let fitView = try request(.canvasFitViewToContent, workspace: workspace, arguments: EmptyWorkspaceActionArguments())

        #expect(WorkspaceActionRegistry.perform(arrange, in: context).success)
        #expect(first.frame.origin == CGPoint(x: 10, y: 20))
        #expect(second.frame.origin == CGPoint(x: 122, y: 20))
        #expect(third.frame.origin == CGPoint(x: 10, y: 114))

        let result = WorkspaceActionRegistry.perform(fitView, in: context)
        #expect(result.success)
        #expect(result.message == "Fit view to content")
        #expect(result.changedObjectIDs.isEmpty)
    }

    @Test func aiDeleteRequiresConfirmationBeforeMutating() throws {
        let (context, workspace) = try makeWorkspace()
        let object = makeObject(in: workspace, context: context)
        let delete = try request(
            .canvasDeleteObjects,
            workspace: workspace,
            arguments: WorkspaceObjectIDsArguments(objectIDs: [object.id]),
            source: .ai
        )

        let unconfirmed = WorkspaceActionRegistry.perform(delete, in: context)

        #expect(!unconfirmed.success)
        #expect(unconfirmed.needsConfirmation)
        #expect((try context.fetch(FetchDescriptor<CanvasObject>())).count == 1)

        let confirmed = WorkspaceActionRegistry.perform(delete, in: context, confirmed: true)

        #expect(confirmed.success)
        #expect(!confirmed.needsConfirmation)
        #expect((try context.fetch(FetchDescriptor<CanvasObject>())).isEmpty)
    }

    private func makeWorkspace() throws -> (ModelContext, Workspace) {
        let container = try ModelContainer(
            for: Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let workspace = Workspace(name: "Actions", isActive: true)
        context.insert(workspace)
        return (context, workspace)
    }

    private func makeObject(
        in workspace: Workspace,
        context: ModelContext,
        x: Double = 0,
        y: Double = 0,
        width: Double = 220,
        height: Double = 140
    ) -> CanvasObject {
        let object = CanvasObject(kind: .stickyNote, workspace: workspace, x: x, y: y, width: width, height: height, text: "Note")
        context.insert(object)
        workspace.canvasObjects.append(object)
        return object
    }

    private func request<T: Encodable>(
        _ name: WorkspaceActionName,
        workspace: Workspace,
        arguments: T,
        source: WorkspaceActionSource = .user
    ) throws -> WorkspaceActionRequest {
        WorkspaceActionRequest(
            name: name,
            workspaceID: workspace.id,
            argumentsData: try JSONEncoder().encode(arguments),
            source: source
        )
    }
}
