import Foundation
import Testing
@testable import ClipCanvas

@Suite struct TransformSkillRegistryTests {
    @Test func registersInitialSkillIDs() {
        let registry = TransformSkillRegistry()
        let ids = Set(registry.skills.map(\.id))

        #expect(ids == [
            "clip.cleanUp",
            "clip.distill",
            "clip.actionItems",
            "clip.rewrite",
            "clip.title",
            "clip.suggestTags",
            "canvas.createStickyNotesFromText",
            "canvas.arrangeIntoGrid",
            "canvas.summarizeVisibleObjects",
            "canvas.createDiagramFromNotes",
        ])
    }

    @Test func chatTransformSkillCatalogMatchesBuiltInTextTransforms() {
        let skills = AITransformSkill.allCases

        #expect(skills.map(\.id) == [
            "clip.cleanUp",
            "clip.distill",
            "clip.actionItems",
            "clip.rewrite",
            "clip.title",
        ])
        #expect(AITransformSkill.matching(message: "please make this a to-do list") == .actionItems)
        #expect(AITransformSkill.matching(message: "summarize the selected cards") == .distill)
    }

    @Test func cleanupUsesDeterministicFallbackWhenProviderUnavailable() async throws {
        let registry = TransformSkillRegistry(provider: FoundationTransformProvider(isAvailable: false))
        let result = try await registry.run(
            "clip.cleanUp",
            input: TransformSkillInput(text: "  Hello   world\n\nfrom   ClipCanvas  ")
        )

        #expect(result.text == "Hello world\nfrom ClipCanvas")
        #expect(result.changedClipIDs.isEmpty)
        #expect(result.proposedActions.isEmpty)
    }

    @Test func titleAndTagsProduceUsefulFallbacks() async throws {
        let registry = TransformSkillRegistry(provider: FoundationTransformProvider(isAvailable: false))
        let title = try await registry.run("clip.title", input: TransformSkillInput(text: "Write an implementation plan for the shared action registry."))
        let tags = try await registry.run("clip.suggestTags", input: TransformSkillInput(text: "https://example.com documentation for SwiftData"))

        #expect(title.text == "Write an implementation plan")
        #expect(tags.suggestedTagNames.contains("Link"))
        #expect(tags.suggestedTagNames.contains("Swift"))
    }

    @Test func shortTextFallbackTransformsStillProduceVisibleChanges() async throws {
        let registry = TransformSkillRegistry(provider: FoundationTransformProvider(isAvailable: false))
        let rewrite = try await registry.run("clip.rewrite", input: TransformSkillInput(text: "buy milk"))
        let actionItems = try await registry.run("clip.actionItems", input: TransformSkillInput(text: "buy milk"))

        #expect(rewrite.text == "Buy milk.")
        #expect(actionItems.text == "- [ ] buy milk")
    }

    @Test func arrangeGridSkillReturnsWorkspaceAction() async throws {
        let workspaceID = UUID()
        let objectIDs = [UUID(), UUID(), UUID()]
        let registry = TransformSkillRegistry(provider: FoundationTransformProvider(isAvailable: false))

        let result = try await registry.run(
            "canvas.arrangeIntoGrid",
            input: TransformSkillInput(workspaceID: workspaceID, objectIDs: objectIDs)
        )

        let action = try #require(result.proposedActions.first)
        #expect(action.name == .canvasArrangeGrid)
        #expect(action.workspaceID == workspaceID)
        #expect(action.source == .user)

        let args = try JSONDecoder().decode(WorkspaceArrangeGridArguments.self, from: action.argumentsData)
        #expect(args.objectIDs == objectIDs)
        #expect(args.columnCount == 2)
    }

    @Test func missingSkillThrowsNotFound() async {
        let registry = TransformSkillRegistry(provider: FoundationTransformProvider(isAvailable: false))

        await #expect(throws: TransformSkillError.skillNotFound("missing")) {
            try await registry.run("missing", input: TransformSkillInput(text: "Test"))
        }
    }
}
