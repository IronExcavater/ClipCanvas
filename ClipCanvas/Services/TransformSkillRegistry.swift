import Foundation

nonisolated struct TransformSkillInput: Codable, Equatable {
    var workspaceID: UUID?
    var objectIDs: [UUID]
    var clipIDs: [UUID]
    var text: String

    init(
        workspaceID: UUID? = nil,
        objectIDs: [UUID] = [],
        clipIDs: [UUID] = [],
        text: String = ""
    ) {
        self.workspaceID = workspaceID
        self.objectIDs = objectIDs
        self.clipIDs = clipIDs
        self.text = text
    }
}

nonisolated struct TransformSkillResult {
    var text: String?
    var suggestedTagNames: [String]
    var changedClipIDs: [UUID]
    var proposedActions: [WorkspaceActionRequest]

    init(
        text: String? = nil,
        suggestedTagNames: [String] = [],
        changedClipIDs: [UUID] = [],
        proposedActions: [WorkspaceActionRequest] = []
    ) {
        self.text = text
        self.suggestedTagNames = suggestedTagNames
        self.changedClipIDs = changedClipIDs
        self.proposedActions = proposedActions
    }
}

nonisolated enum TransformSkillError: Error, Equatable {
    case skillNotFound(String)
    case missingWorkspace
}

protocol TransformSkill {
    var id: String { get }
    var title: String { get }
    var risk: WorkspaceActionRisk { get }
    func run(input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult
}

struct TransformSkillRegistry {
    let skills: [any TransformSkill]
    private let provider: FoundationTransformProvider

    init(provider: FoundationTransformProvider = FoundationTransformProvider()) {
        self.provider = provider
        self.skills = [
            BuiltInTransformSkill(id: "clip.cleanUp", title: "Clean Up", risk: .changesContent, handler: Self.cleanUp),
            BuiltInTransformSkill(id: "clip.distill", title: "Distill", risk: .changesContent, handler: Self.distill),
            BuiltInTransformSkill(id: "clip.actionItems", title: "Action Items", risk: .changesContent, handler: Self.actionItems),
            BuiltInTransformSkill(id: "clip.rewrite", title: "Rewrite", risk: .changesContent, handler: Self.rewrite),
            BuiltInTransformSkill(id: "clip.title", title: "Title", risk: .safe, handler: Self.title),
            BuiltInTransformSkill(id: "clip.suggestTags", title: "Suggest Tags", risk: .safe, handler: Self.suggestTags),
            BuiltInTransformSkill(id: "canvas.createStickyNotesFromText", title: "Create Sticky Notes", risk: .changesContent, handler: Self.createStickyNotes),
            BuiltInTransformSkill(id: "canvas.arrangeIntoGrid", title: "Arrange Grid", risk: .changesContent, handler: Self.arrangeIntoGrid),
            BuiltInTransformSkill(id: "canvas.summarizeVisibleObjects", title: "Summarize Visible Cards", risk: .safe, handler: Self.summarizeVisibleObjects),
            BuiltInTransformSkill(id: "canvas.createDiagramFromNotes", title: "Create Diagram", risk: .changesContent, handler: Self.createDiagramFromNotes),
        ]
    }

    func run(_ id: String, input: TransformSkillInput) async throws -> TransformSkillResult {
        guard let skill = skills.first(where: { $0.id == id }) else {
            throw TransformSkillError.skillNotFound(id)
        }
        return try await skill.run(input: input, provider: provider)
    }
}

private struct BuiltInTransformSkill: TransformSkill {
    let id: String
    let title: String
    let risk: WorkspaceActionRisk
    let handler: (String, TransformSkillInput, FoundationTransformProvider) async throws -> TransformSkillResult

    func run(input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        try await handler(id, input, provider)
    }
}

private extension TransformSkillRegistry {
    static func cleanUp(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        if let text = try await provider.transform(skillID: id, input: input) {
            return TransformSkillResult(text: text)
        }
        return TransformSkillResult(text: collapseWhitespace(input.text))
    }

    static func distill(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        if let text = try await provider.transform(skillID: id, input: input) {
            return TransformSkillResult(text: text)
        }
        let cleaned = collapseWhitespace(input.text)
        let sentenceEnd = cleaned.firstIndex(where: { ".!?".contains($0) })
        if let sentenceEnd {
            return TransformSkillResult(text: String(cleaned[...sentenceEnd]))
        }
        return TransformSkillResult(text: String(cleaned.prefix(180)))
    }

    static func actionItems(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        if let text = try await provider.transform(skillID: id, input: input) {
            return TransformSkillResult(text: text)
        }
        let clauses = input.text
            .components(separatedBy: CharacterSet(charactersIn: ".\n"))
            .map { collapseWhitespace($0) }
            .filter { !$0.isEmpty }
        let items = clauses.prefix(5).map { "- \($0)" }.joined(separator: "\n")
        return TransformSkillResult(text: items)
    }

    static func rewrite(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        if let text = try await provider.transform(skillID: id, input: input) {
            return TransformSkillResult(text: text)
        }
        return TransformSkillResult(text: collapseWhitespace(input.text))
    }

    static func title(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        if let text = try await provider.transform(skillID: id, input: input) {
            return TransformSkillResult(text: text)
        }
        let words = collapseWhitespace(input.text)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let stopWords = Set(["for", "to", "and", "or", "of", "the", "a", "an"])
        var titleWords = Array(words.prefix(5))
        while let last = titleWords.last?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,:;")),
              stopWords.contains(last) {
            titleWords.removeLast()
        }
        return TransformSkillResult(text: titleWords.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ".,:;")))
    }

    static func suggestTags(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        _ = try await provider.transform(skillID: id, input: input)
        let lower = input.text.lowercased()
        var tags: [String] = []
        if lower.contains("http://") || lower.contains("https://") { tags.append("Link") }
        if lower.contains("swift") || lower.contains("swiftdata") || lower.contains("swiftui") { tags.append("Swift") }
        if lower.contains("todo") || lower.contains("action") { tags.append("Action") }
        if tags.isEmpty { tags.append("Note") }
        return TransformSkillResult(suggestedTagNames: tags)
    }

    static func createStickyNotes(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        guard let workspaceID = input.workspaceID else { throw TransformSkillError.missingWorkspace }
        let text = try await provider.transform(skillID: id, input: input) ?? collapseWhitespace(input.text)
        let arguments = WorkspaceCreateStickyNoteArguments(
            text: text,
            x: 0,
            y: 0,
            width: CanvasPlacementSizing.defaultSize.width,
            height: CanvasPlacementSizing.defaultSize.height,
            style: .default
        )
        return TransformSkillResult(proposedActions: [try request(.canvasCreateStickyNote, workspaceID: workspaceID, arguments: arguments)])
    }

    static func arrangeIntoGrid(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        guard let workspaceID = input.workspaceID else { throw TransformSkillError.missingWorkspace }
        let columns = max(1, Int(ceil(sqrt(Double(max(input.objectIDs.count, 1))))))
        let arguments = WorkspaceArrangeGridArguments(
            objectIDs: input.objectIDs,
            originX: 0,
            originY: 0,
            columnCount: columns,
            horizontalSpacing: 22,
            verticalSpacing: 22
        )
        return TransformSkillResult(proposedActions: [try request(.canvasArrangeGrid, workspaceID: workspaceID, arguments: arguments)])
    }

    static func summarizeVisibleObjects(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        if let text = try await provider.transform(skillID: id, input: input) {
            return TransformSkillResult(text: text)
        }
        return TransformSkillResult(text: "Visible cards: \(input.objectIDs.count)")
    }

    static func createDiagramFromNotes(id: String, input: TransformSkillInput, provider: FoundationTransformProvider) async throws -> TransformSkillResult {
        if let text = try await provider.transform(skillID: id, input: input) {
            return TransformSkillResult(text: text)
        }
        return TransformSkillResult(text: "Diagram draft from \(input.objectIDs.count) cards")
    }

    static func request<T: Encodable>(_ name: WorkspaceActionName, workspaceID: UUID, arguments: T) throws -> WorkspaceActionRequest {
        WorkspaceActionRequest(
            name: name,
            workspaceID: workspaceID,
            argumentsData: try JSONEncoder().encode(arguments),
            source: .user
        )
    }

    static func collapseWhitespace(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
