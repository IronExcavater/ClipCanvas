import Foundation

nonisolated struct AIModelPreset: Codable, Equatable {
    var mode: AIChatMode
    var model: String
    var reasoningEffort: String
    var maxContextObjects: Int
}

enum AIModelPresetService {
    static func preset(for mode: AIChatMode) -> AIModelPreset {
        switch mode {
        case .quick:
            AIModelPreset(mode: .quick, model: "gpt-5.4-mini", reasoningEffort: "none", maxContextObjects: 8)
        case .thinking:
            AIModelPreset(mode: .thinking, model: "gpt-5.5", reasoningEffort: "high", maxContextObjects: 32)
        }
    }
}

nonisolated enum AIContextItemSource: String, Codable, Equatable {
    case attachment
    case selectedObject
    case visibleObject
    case recentHistory
}

nonisolated struct AIContextWorkspaceSummary: Codable, Equatable {
    var id: UUID
    var name: String
    var totalObjectCount: Int
    var visibleObjectCount: Int
    var selectedObjectCount: Int
    var privateObjectCount: Int
}

nonisolated struct AIContextItem: Codable, Equatable, Identifiable {
    var id: UUID
    var source: AIContextItemSource
    var objectID: UUID?
    var clipID: UUID?
    var kind: String
    var content: String?
    var isPrivate: Bool
    var note: String?
}

nonisolated struct AIContextSnapshot: Codable, Equatable {
    var mode: AIChatMode
    var model: AIModelPreset
    var workspace: AIContextWorkspaceSummary
    var items: [AIContextItem]
    var privateOmittedCount: Int
}

enum AIContextPacker {
    static func pack(
        chat: AIChat,
        workspace: Workspace,
        mode: AIChatMode,
        selectedObjectIDs: Set<UUID>,
        visibleObjectIDs: Set<UUID>,
        recentClips: [Clip]
    ) -> AIContextSnapshot {
        let preset = AIModelPresetService.preset(for: mode)
        let liveObjects = workspace.canvasObjects.filter(\.isVisible)
        let objectByID = Dictionary(uniqueKeysWithValues: liveObjects.map { ($0.id, $0) })
        var items: [AIContextItem] = []
        var seenKeys = Set<String>()
        var privateOmittedClipIDs = Set<UUID>()

        for attachment in attachments(from: chat) {
            let item: AIContextItem?
            if let object = attachment.canvasObject {
                guard object.isVisible else { continue }
                item = self.item(for: object, source: .attachment)
            } else if let clip = attachment.clip {
                item = self.item(for: clip, source: .attachment)
            } else {
                item = nil
            }
            guard let item else { continue }
            append(item, to: &items, seenKeys: &seenKeys, privateOmittedClipIDs: &privateOmittedClipIDs)
        }

        for object in orderedObjects(ids: selectedObjectIDs, objectByID: objectByID) {
            let item = item(for: object, source: .selectedObject)
            append(item, to: &items, seenKeys: &seenKeys, privateOmittedClipIDs: &privateOmittedClipIDs)
        }

        for object in orderedObjects(ids: visibleObjectIDs.subtracting(selectedObjectIDs), objectByID: objectByID) {
            let item = item(for: object, source: .visibleObject)
            append(item, to: &items, seenKeys: &seenKeys, privateOmittedClipIDs: &privateOmittedClipIDs)
        }

        for clip in recentClips where items.count < preset.maxContextObjects {
            let item = item(for: clip, source: .recentHistory)
            append(item, to: &items, seenKeys: &seenKeys, privateOmittedClipIDs: &privateOmittedClipIDs)
        }

        let limitedItems = Array(items.prefix(preset.maxContextObjects))
        let selectedCount = liveObjects.filter { selectedObjectIDs.contains($0.id) }.count
        let visibleCount = liveObjects.filter { visibleObjectIDs.contains($0.id) }.count
        let privateObjectCount = liveObjects.filter { $0.clip?.sensitivity == .privateContent }.count

        return AIContextSnapshot(
            mode: mode,
            model: preset,
            workspace: AIContextWorkspaceSummary(
                id: workspace.id,
                name: workspace.name,
                totalObjectCount: liveObjects.count,
                visibleObjectCount: visibleCount,
                selectedObjectCount: selectedCount,
                privateObjectCount: privateObjectCount
            ),
            items: limitedItems,
            privateOmittedCount: privateOmittedClipIDs.count
        )
    }
}

private extension AIContextPacker {
    static func attachments(from chat: AIChat) -> [ChatAttachment] {
        chat.sortedMessages.flatMap { message in
            message.sortedAttachments
        }
    }

    static func orderedObjects(ids: Set<UUID>, objectByID: [UUID: CanvasObject]) -> [CanvasObject] {
        ids.compactMap { objectByID[$0] }
            .sorted { lhs, rhs in
                if lhs.zIndex == rhs.zIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.zIndex < rhs.zIndex
            }
    }

    static func item(for object: CanvasObject, source: AIContextItemSource) -> AIContextItem {
        if let clip = object.clip {
            return item(for: clip, source: source, objectID: object.id, kind: object.kind.rawValue)
        }
        return AIContextItem(
            id: object.id,
            source: source,
            objectID: object.id,
            clipID: nil,
            kind: object.kind.rawValue,
            content: trimmed(object.text),
            isPrivate: false,
            note: nil
        )
    }

    static func item(for clip: Clip, source: AIContextItemSource, objectID: UUID? = nil, kind: String? = nil) -> AIContextItem {
        let isPrivate = clip.sensitivity == .privateContent
        return AIContextItem(
            id: objectID ?? clip.id,
            source: source,
            objectID: objectID,
            clipID: clip.id,
            kind: kind ?? clip.type.rawValue,
            content: isPrivate ? nil : trimmed(clip.content),
            isPrivate: isPrivate,
            note: isPrivate ? "Private clip omitted" : nil
        )
    }

    static func append(
        _ item: AIContextItem,
        to items: inout [AIContextItem],
        seenKeys: inout Set<String>,
        privateOmittedClipIDs: inout Set<UUID>
    ) {
        let key = item.objectID?.uuidString ?? item.clipID?.uuidString ?? item.id.uuidString
        guard !seenKeys.contains(key) else { return }
        seenKeys.insert(key)
        if item.isPrivate, let clipID = item.clipID {
            privateOmittedClipIDs.insert(clipID)
        }
        items.append(item)
    }

    static func trimmed(_ text: String, maxLength: Int = 2_000) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<end])
    }
}
