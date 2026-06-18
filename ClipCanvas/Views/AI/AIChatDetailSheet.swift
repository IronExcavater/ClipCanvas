import SwiftData
import SwiftUI

struct AIChatDetailSheet: View {
    @Bindable var chat: AIChat

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AIChatDetailView(chat: chat, onClose: { dismiss() })
            .appSheetPresentationDetents()
    }
}

struct AIChatDetailView: View {
    @Bindable var chat: AIChat

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Clip> { $0.deletedAt == nil }) private var clips: [Clip]
    @Query(filter: #Predicate<CanvasObject> { $0.deletedAt == nil }) private var canvasObjects: [CanvasObject]
    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }) private var workspaces: [Workspace]
    @Query(filter: #Predicate<AIChat> { $0.deletedAt == nil }) private var chats: [AIChat]

    var onClose: (() -> Void)?

    @State private var input = ""
    @State private var inputHeight: CGFloat = 42
    @State private var inputEditorID = UUID()
    @State private var isSending = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var confirmingDelete = false
    @State private var linkedClip: Clip?
    @State private var linkedChat: AIChat?

    private var canSend: Bool {
        !isSending && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    messageList
                    inputBar
                }

                if confirmingDelete {
                    AppConfirmationOverlay(
                        title: "Delete this chat?",
                        message: "The chat will move to Recently Deleted.",
                        destructiveTitle: "Delete",
                        onConfirm: deleteChat,
                        onCancel: { confirmingDelete = false }
                    )
                    .zIndex(20)
                }
            }
            .navigationTitle("")
            .appInlineNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) {
                        AppCircleIconLabel(systemImage: "xmark", size: 36, symbolSize: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .principal) {
                    titleView
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Rename", systemImage: "pencil") { beginRename() }
                        Button("Delete Chat", systemImage: "trash", role: .destructive) {
                            confirmingDelete = true
                        }
                    } label: {
                        AppCircleIconLabel(systemImage: AppSymbol.options, size: 36, symbolSize: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Chat options")
                }
            }
        }
        .environment(\.openURL, OpenURLAction(handler: handleOpenURL))
        .sheet(item: $linkedClip) { ClipDetailSheet(clip: $0) }
        .sheet(item: $linkedChat) { AIChatDetailSheet(chat: $0) }
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: confirmingDelete)
    }

    @ViewBuilder
    private var titleView: some View {
        if isRenaming {
            TextField("Chat name", text: $renameText)
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit(commitRename)
                .onDisappear {
                    if isRenaming { commitRename() }
                }
                .frame(maxWidth: 220)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassCapsule(shadow: false, interactive: true)
        } else {
            Text(chat.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if chat.sortedMessages.isEmpty {
                        ContentUnavailableView(
                            "No Messages",
                            systemImage: "sparkles"
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }

                    ForEach(chat.sortedMessages) { message in
                        AIChatMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
                .padding(.bottom, 8)
            }
            .onChange(of: chat.sortedMessages.count) { _, _ in
                if let id = chat.sortedMessages.last?.id {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            markdownInput

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(canSend ? Color.accentColor : Color.secondary.opacity(0.28), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background {
            AppGlassSurface(shape: .rect(cornerRadius: 0))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var markdownInput: some View {
        ZStack(alignment: .topLeading) {
            NoteTextEditor(
                initialText: input,
                fontSize: 15,
                command: nil,
                onCommit: { input = $0 },
                onExitEditing: {},
                onSizeChange: { size in
                    inputHeight = (size.height + 4).clamped(to: 42...138)
                }
            )
            .id(inputEditorID)
            .frame(minHeight: 42, maxHeight: inputHeight)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Message")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 18, shadow: false, interactive: true)
    }

    private func beginRename() {
        renameText = chat.title
        isRenaming = true
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chat.title = trimmed
        chat.updatedAt = Date()
        isRenaming = false
    }

    private func deleteChat() {
        chat.softDelete()
        confirmingDelete = false
        close()
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        input = ""
        inputEditorID = UUID()
        if chat.messages.isEmpty {
            chat.title = String(trimmed.prefix(42))
        }

        let user = ChatMessage(role: .user, content: trimmed)
        user.chat = chat
        chat.messages.append(user)
        context.insert(user)

        let assistant = ChatMessage(role: .assistant, content: "")
        assistant.status = .streaming
        assistant.chat = chat
        chat.messages.append(assistant)
        context.insert(assistant)
        chat.updatedAt = Date()

        isSending = true
        Task {
            await AIChatCommandRouter.respond(to: user, with: assistant, in: context)
            isSending = false
        }
    }

    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "clipcanvas", let host = url.host() else {
            return .systemAction
        }
        let idText = url.pathComponents.dropFirst().first
        guard let idText, let id = UUID(uuidString: idText) else {
            return .discarded
        }

        switch host {
        case "object":
            if let clip = canvasObjects.first(where: { $0.id == id })?.clip {
                linkedClip = clip
                return .handled
            }
        case "clip":
            if let clip = clips.first(where: { $0.id == id }) {
                linkedClip = clip
                return .handled
            }
        case "chat":
            if let linked = chats.first(where: { $0.id == id }), linked.id != chat.id {
                linkedChat = linked
                return .handled
            }
        case "workspace":
            if let workspace = workspaces.first(where: { $0.id == id }) {
                WorkspaceActionService.activate(workspace, among: workspaces)
                return .handled
            }
        default:
            break
        }
        return .discarded
    }
}

private struct AIChatMessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }
    private var hasVisibleContent: Bool { !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if hasVisibleContent {
                HStack {
                    if isUser { Spacer(minLength: 44) }
                    MarkdownPreview(text: message.content)
                        .font(.body)
                        .foregroundStyle(isUser ? .white : .primary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            isUser ? Color.accentColor : assistantBubbleColor,
                            in: bubbleShape
                        )
                        .overlay {
                            if !isUser {
                                bubbleShape.stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                            }
                        }
                    if !isUser { Spacer(minLength: 44) }
                }
            }

            ForEach(message.sortedAttachments) { attachment in
                HStack {
                    if isUser { Spacer(minLength: 44) }
                    AIChatAttachmentRow(attachment: attachment)
                    if !isUser { Spacer(minLength: 44) }
                }
            }

            ForEach(message.sortedToolEvents) { event in
                HStack {
                    if isUser { Spacer(minLength: 44) }
                    AIChatToolEventRow(event: event)
                    if !isUser { Spacer(minLength: 44) }
                }
            }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 18,
                bottomLeading: isUser ? 16 : 4,
                bottomTrailing: isUser ? 4 : 16,
                topTrailing: 18
            ),
            style: .continuous
        )
    }

    private var assistantBubbleColor: Color {
        Color.adaptive(light: PlatformColor.secondarySystemBackground, dark: PlatformColor.secondarySystemBackground)
            .opacity(0.92)
    }
}

private struct AIChatAttachmentRow: View {
    let attachment: ChatAttachment

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.state == .live ? "paperclip" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(attachment.state == .live ? Color.accentColor : .orange)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(attachment.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AIChatToolEventRow: View {
    let event: AIToolEvent

    var body: some View {
        HStack(spacing: 8) {
            if event.status == .running || event.status == .queued {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: event.status.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(event.status.tint)
                    .frame(width: 18, height: 18)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(event.toolName.displayToolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(event.status.tint.opacity(0.20), lineWidth: 1)
        }
    }
}

private extension ChatAttachment {
    var title: String {
        let text = canvasObject?.displayText ?? clip?.content ?? "Deleted attachment"
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Canvas attachment" }
        return String(trimmed.prefix(64))
    }

    var subtitle: String {
        switch state {
        case .live:
            if canvasObject != nil { return "Attached canvas card" }
            return "Attached clipboard item"
        case .softDeleted:
            return "Attachment is in Recently Deleted"
        case .hardDeleted:
            return "Attachment is no longer available"
        }
    }
}

private extension AIToolEventStatus {
    var symbolName: String {
        switch self {
        case .queued:
            return "clock"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .needsConfirmation:
            return "exclamationmark.shield.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .queued, .running:
            return .secondary
        case .needsConfirmation:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

private extension String {
    var displayToolName: String {
        replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
    }
}
