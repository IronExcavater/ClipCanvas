import Foundation

nonisolated enum AppReferenceLink {
    static func workspace(_ workspace: Workspace) -> String {
        markdown(title: workspace.name, url: "clipcanvas://workspace/\(workspace.id.uuidString)")
    }

    static func object(_ object: CanvasObject, fallbackTitle: String = "Canvas card") -> String {
        let title = object.displayText
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? fallbackTitle
        return markdown(title: title, url: "clipcanvas://object/\(object.id.uuidString)")
    }

    static func clip(_ clip: Clip, fallbackTitle: String = "Clipboard item") -> String {
        let title = clip.preview
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? fallbackTitle
        return markdown(title: title, url: "clipcanvas://clip/\(clip.id.uuidString)")
    }

    static func chat(_ chat: AIChat) -> String {
        markdown(title: chat.title, url: "clipcanvas://chat/\(chat.id.uuidString)")
    }

    private static func markdown(title: String, url: String) -> String {
        let escaped = title
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escaped)](\(url))"
    }
}

nonisolated enum AIChatPromptBuilder {
    static let instructions = """
    You are ClipCanvas, a concise assistant embedded in a canvas notes app.
    Answer directly and avoid describing implementation status.
    When you mention a workspace, canvas card, clipboard item, or chat, use the exact markdown links provided in the context.
    If a user asks to mutate content, prefer clear action wording and do not invent results.
    """

    static func input(for userMessage: ChatMessage, chat: AIChat, workspace: Workspace) -> String {
        [
            "Workspace: \(AppReferenceLink.workspace(workspace))",
            "Current chat: \(AppReferenceLink.chat(chat))",
            visibleCardsSection(workspace: workspace),
            attachmentsSection(chat: chat),
            transcriptSection(chat: chat, excluding: userMessage.id),
            "User request:\n\(userMessage.content)"
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }

    private static func visibleCardsSection(workspace: Workspace) -> String {
        let objects = workspace.canvasObjects
            .filter { $0.isVisible && $0.kind != .connector }
            .sorted { lhs, rhs in
                if lhs.zIndex == rhs.zIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.zIndex < rhs.zIndex
            }
        guard !objects.isEmpty else { return "Visible canvas cards: none" }
        let lines = objects.prefix(12).map { object in
            let body = object.displayText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .nilIfEmpty ?? object.kind.rawValue
            return "- \(AppReferenceLink.object(object)): \(String(body.prefix(240)))"
        }
        return "Visible canvas cards:\n" + lines.joined(separator: "\n")
    }

    private static func attachmentsSection(chat: AIChat) -> String {
        let attachments = chat.sortedMessages.flatMap(\.sortedAttachments)
        guard !attachments.isEmpty else { return "" }
        let lines = attachments.prefix(12).map { attachment in
            if let object = attachment.canvasObject {
                return "- \(AppReferenceLink.object(object)): \(subtitle(for: attachment))"
            }
            if let clip = attachment.clip {
                return "- \(AppReferenceLink.clip(clip)): \(subtitle(for: attachment))"
            }
            return "- Deleted attachment"
        }
        return "Attached context:\n" + lines.joined(separator: "\n")
    }

    private static func subtitle(for attachment: ChatAttachment) -> String {
        switch attachment.state {
        case .live:
            attachment.canvasObject != nil ? "Attached canvas card" : "Attached clipboard item"
        case .softDeleted:
            "Attachment is in Recently Deleted"
        case .hardDeleted:
            "Attachment is no longer available"
        }
    }

    private static func transcriptSection(chat: AIChat, excluding messageID: UUID) -> String {
        let messages = chat.sortedMessages
            .filter { $0.id != messageID && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(8)
        guard !messages.isEmpty else { return "" }
        let lines = messages.map { message in
            "\(message.role.rawValue): \(message.content.prefix(800))"
        }
        return "Recent conversation:\n" + lines.joined(separator: "\n")
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
