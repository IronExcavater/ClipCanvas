import Foundation

nonisolated enum AppReferenceLink {
    static func workspace(_ workspace: Workspace) -> String {
        markdown(title: workspace.name, url: "clipcanvas://workspace/\(workspace.id.uuidString)")
    }

    static func object(_ object: CanvasObject, fallbackTitle: String = "Canvas card") -> String {
        let title: String
        if object.clip?.sensitivity == .privateContent {
            title = fallbackTitle
        } else {
            title = object.displayText
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? fallbackTitle
        }
        return markdown(title: title, url: "clipcanvas://object/\(object.id.uuidString)")
    }

    static func clip(_ clip: Clip, fallbackTitle: String = "Clipboard item") -> String {
        let title: String
        if clip.sensitivity == .privateContent {
            title = fallbackTitle
        } else {
            title = clip.preview
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? fallbackTitle
        }
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
    The app can execute ClipCanvas actions through tool events: create sticky notes, create clipboard-backed notes, update object text, move, resize, duplicate, group, ungroup, arrange, delete with confirmation, update clips, add/remove tags, attach cards to chats, and transform text.
    Text content is markdown-capable. Supported formatting includes title, heading, subheading, body, monostyled, bold, italic, underline, strikethrough, colored highlights, bullet/dashed/numbered/check lists, quote blocks, links, indent/outdent, and sensitive spans using ||sensitive text||.
    If a user asks to mutate content, prefer clear action wording and only claim changes that were made by tool events.
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
            .filter(\.isCanvasContent)
            .sorted { lhs, rhs in
                if lhs.zIndex == rhs.zIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.zIndex < rhs.zIndex
            }
        guard !objects.isEmpty else { return "Visible canvas cards: none" }
        let lines = objects.prefix(12).map { object in
            let body = objectContentSummary(object, fallback: object.kind.rawValue, limit: 240)
            return "- \(AppReferenceLink.object(object)): \(String(body.prefix(240)))"
        }
        return "Visible canvas cards:\n" + lines.joined(separator: "\n")
    }

    private static func attachmentsSection(chat: AIChat) -> String {
        let attachments = chat.sortedMessages.flatMap(\.sortedAttachments)
        guard !attachments.isEmpty else { return "" }
        let lines = attachments.prefix(12).map { attachment in
            if let object = attachment.canvasObject {
                return "- \(AppReferenceLink.object(object)): \(description(for: attachment, object: object))"
            }
            if let clip = attachment.clip {
                return "- \(AppReferenceLink.clip(clip)): \(description(for: attachment, clip: clip))"
            }
            return "- Deleted attachment"
        }
        return "Attached context:\n" + lines.joined(separator: "\n")
    }

    private static func description(for attachment: ChatAttachment, object: CanvasObject) -> String {
        let label = stateDescription(for: attachment, liveLabel: "Attached canvas card")
        guard attachment.state == .live else { return label }
        if let clip = object.clip {
            return "\(label), \(contentDescription(for: clip))"
        }
        let content = compactContent(object.text)
        return content.isEmpty ? "\(label), content: empty" : "\(label), content: \(content)"
    }

    private static func description(for attachment: ChatAttachment, clip: Clip) -> String {
        let label = stateDescription(for: attachment, liveLabel: "Attached clipboard item")
        guard attachment.state == .live else { return label }
        return "\(label), \(contentDescription(for: clip))"
    }

    private static func stateDescription(for attachment: ChatAttachment, liveLabel: String) -> String {
        switch attachment.state {
        case .live:
            liveLabel
        case .softDeleted:
            "Attachment is in Recently Deleted"
        case .hardDeleted:
            "Attachment is no longer available"
        }
    }

    private static func contentDescription(for clip: Clip) -> String {
        if clip.sensitivity == .privateContent {
            return "content: private"
        }
        if clip.type == .image {
            return "image: \(clip.imageName?.nilIfEmpty ?? "unnamed image")"
        }
        let content = compactContent(clip.content)
        return content.isEmpty ? "content: empty" : "content: \(content)"
    }

    private static func objectContentSummary(_ object: CanvasObject, fallback: String, limit: Int) -> String {
        if let clip = object.clip {
            if clip.sensitivity == .privateContent {
                return "private content"
            }
            if clip.type == .image {
                return clip.imageName?.nilIfEmpty ?? "image"
            }
            return compactContent(clip.content, limit: limit).nilIfEmpty ?? fallback
        }
        return compactContent(object.text, limit: limit).nilIfEmpty ?? fallback
    }

    private static func compactContent(_ content: String, limit: Int = 800) -> String {
        let compact = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard compact.count > limit else { return compact }
        let end = compact.index(compact.startIndex, offsetBy: limit)
        return String(compact[..<end])
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
