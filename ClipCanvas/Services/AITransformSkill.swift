import Foundation
import SwiftData

nonisolated enum AITransformSkill: String, CaseIterable, Identifiable {
    case cleanUp = "clip.cleanUp"
    case distill = "clip.distill"
    case actionItems = "clip.actionItems"
    case rewrite = "clip.rewrite"
    case title = "clip.title"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleanUp: "Clean Up"
        case .distill: "Distill"
        case .actionItems: "Action Items"
        case .rewrite: "Rewrite"
        case .title: "Title"
        }
    }

    var systemImage: String {
        switch self {
        case .cleanUp: "wand.and.sparkles"
        case .distill: "text.badge.checkmark"
        case .actionItems: "checklist"
        case .rewrite: "pencil.and.outline"
        case .title: "textformat.size"
        }
    }

    var prompt: String {
        switch self {
        case .cleanUp: "Clean up the attached cards"
        case .distill: "Distill the attached cards"
        case .actionItems: "Convert the attached cards into action items"
        case .rewrite: "Rewrite the attached cards"
        case .title: "Generate titles for the attached cards"
        }
    }

    var matchingPhrases: [String] {
        switch self {
        case .cleanUp: ["clean up", "cleanup", "tidy", "fix spacing"]
        case .distill: ["distill", "summarize", "summary", "make concise", "shorten", "condense"]
        case .actionItems: ["action item", "action items", "todo", "to-do", "to do", "checklist", "task list"]
        case .rewrite: ["rewrite", "reword", "improve wording", "make clearer"]
        case .title: ["title", "headline", "name this"]
        }
    }

    static func matching(message: String) -> AITransformSkill? {
        let lower = message.lowercased()
        return allCases.first { skill in
            skill.matchingPhrases.contains { lower.contains($0) }
        }
    }

    func completion(for result: WorkspaceActionResult) -> String {
        guard result.success else { return result.message }
        let count = result.changedClipIDs.isEmpty
            ? result.changedObjectIDs.count
            : result.changedClipIDs.count
        let noun = count == 1 ? "note" : "notes"
        switch self {
        case .cleanUp:
            return "Cleaned up \(count) \(noun)."
        case .distill:
            return "Distilled \(count) \(noun)."
        case .actionItems:
            return "Converted \(count) \(noun) into action items."
        case .rewrite:
            return "Rewrote \(count) \(noun)."
        case .title:
            return "Generated titles for \(count) \(noun)."
        }
    }
}

enum AITransformActionService {
    static func apply(
        _ skill: AITransformSkill,
        to objects: [CanvasObject],
        workspace: Workspace,
        in context: ModelContext,
        source: WorkspaceActionSource = .user
    ) -> WorkspaceActionResult {
        let targets = unique(objects.filter(\.isCanvasContent))
        guard !targets.isEmpty else {
            return .failure("Select a text card first.")
        }

        let clipIDs = unique(targets.compactMap(\.clip).filter { $0.deletedAt == nil }).map(\.id)
        let textObjects = targets.filter {
            $0.clip == nil && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var changedObjectIDs: [UUID] = []
        var changedClipIDs: [UUID] = []
        var failureMessage: String?

        if !clipIDs.isEmpty {
            let result = perform(
                .clipApplyTransform,
                workspaceID: workspace.id,
                arguments: WorkspaceClipApplyTransformArguments(clipIDs: clipIDs, skillID: skill.id),
                source: source,
                in: context
            )
            if result.success {
                changedClipIDs.append(contentsOf: result.changedClipIDs)
            } else {
                failureMessage = result.message
            }
        }

        for object in textObjects {
            guard let transformed = TextTransformFallbacks.text(for: skill.id, input: object.text) else {
                failureMessage = "Transform not found"
                continue
            }
            let result = perform(
                .canvasUpdateObjectText,
                workspaceID: workspace.id,
                arguments: WorkspaceUpdateObjectTextArguments(objectID: object.id, text: transformed),
                source: source,
                in: context
            )
            if result.success {
                changedObjectIDs.append(contentsOf: result.changedObjectIDs)
            } else {
                failureMessage = result.message
            }
        }

        if !changedObjectIDs.isEmpty || !changedClipIDs.isEmpty {
            return .success(
                "Applied \(skill.title)",
                changedObjectIDs: changedObjectIDs,
                changedClipIDs: changedClipIDs
            )
        }
        return .failure(failureMessage ?? "Select a text card first.")
    }

    private static func perform<T: Encodable>(
        _ name: WorkspaceActionName,
        workspaceID: UUID,
        arguments: T,
        source: WorkspaceActionSource,
        in context: ModelContext
    ) -> WorkspaceActionResult {
        do {
            let request = WorkspaceActionRequest(
                name: name,
                workspaceID: workspaceID,
                argumentsData: try JSONEncoder().encode(arguments),
                source: source
            )
            return WorkspaceActionRegistry.perform(request, in: context, confirmed: true)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private static func unique(_ objects: [CanvasObject]) -> [CanvasObject] {
        var seen = Set<UUID>()
        return objects.filter { seen.insert($0.id).inserted }
    }

    private static func unique(_ clips: [Clip]) -> [Clip] {
        var seen = Set<UUID>()
        return clips.filter { seen.insert($0.id).inserted }
    }
}
