import SwiftData
import Testing
@testable import ClipCanvas

@Suite struct WorkspaceActionServiceTests {
    @Test func createdWorkspaceSortsBeforeExistingWorkspaces() throws {
        let context = try makeContext()
        let first = Workspace(name: "First", sortIndex: 0, isActive: true)
        let second = Workspace(name: "Second", sortIndex: 1)
        context.insert(first)
        context.insert(second)

        let created = WorkspaceActionService.create(in: context, existing: [first, second], name: "")

        #expect(created.sortIndex == -1)
        #expect(created.isActive)
        #expect(!first.isActive)
        #expect(!second.isActive)
    }

    @Test func renameTrimsAndLimitsWorkspaceNames() throws {
        let workspace = Workspace(name: "Old")
        let longName = "   " + String(repeating: "Very Long Workspace Name ", count: 5)

        WorkspaceActionService.rename(workspace, to: longName)

        #expect(workspace.name.count == WorkspaceNamePolicy.maximumLength)
        #expect(!workspace.name.hasPrefix(" "))
        #expect(!workspace.name.hasSuffix(" "))
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Clip.self, ClipTag.self, Workspace.self, CanvasPlacement.self, CanvasObject.self,
            AIChat.self, ChatMessage.self, ChatAttachment.self, AIToolEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}
