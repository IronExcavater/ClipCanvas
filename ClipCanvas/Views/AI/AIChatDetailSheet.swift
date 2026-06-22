import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var inputHeight: CGFloat = 38
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
                        Button("New Chat", systemImage: "plus.bubble") { createNewChat() }
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
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(16)
                .padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.18), value: chat.sortedMessages.count)
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
            aiOptionsButton

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
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var aiOptionsButton: some View {
        Menu {
            ForEach(AIChatMode.allCases, id: \.self) { mode in
                Button {
                    chat.setMode(mode)
                } label: {
                    Label(mode.displayName, systemImage: chat.mode == mode ? "checkmark" : mode.systemImage)
                }
            }

            Menu("Skills", systemImage: "wand.and.sparkles") {
                ForEach(AITransformSkill.allCases) { skill in
                    Button {
                        send(skill: skill)
                    } label: {
                        Label(skill.title, systemImage: skill.systemImage)
                    }
                    .disabled(isSending)
                }
            }
        } label: {
            AppToolbarCircleLabel(systemImage: chat.mode.systemImage, size: 36, symbolSize: 15)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI options")
    }

    private var markdownInput: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AIChatGrowingTextView(text: $input, calculatedHeight: $inputHeight)
                    .frame(height: inputHeight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)

                if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Message")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }

            if showsInputPreview {
                Divider()
                    .padding(.horizontal, 12)
                MarkdownPreview(text: input)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.76))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 16, shadow: false, interactive: true)
    }

    private var showsInputPreview: Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("\n- ")
            || trimmed.contains("\n* ")
            || trimmed.contains("\n• ")
            || trimmed.contains("\n1. ")
            || trimmed.contains("**")
            || trimmed.contains("==")
            || trimmed.contains("[")
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

    private func createNewChat() {
        let workspace = chat.workspace ?? activeWorkspace
        linkedChat = AIChatService.createChat(in: context, workspace: workspace)
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sendMessage(trimmed, clearInput: true)
    }

    private func send(skill: AITransformSkill) {
        guard !isSending else { return }
        sendMessage(skill.prompt, clearInput: false)
    }

    private func sendMessage(_ text: String, clearInput: Bool) {
        if clearInput {
            input = ""
            inputHeight = 38
        }
        if shouldUpdateTitle(from: chat) {
            chat.title = Self.title(for: text)
        }

        let user = ChatMessage(role: .user, content: text)
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

    private func shouldUpdateTitle(from chat: AIChat) -> Bool {
        if chat.title == "New Chat" { return true }
        guard let workspace = chat.workspace else { return chat.sortedMessages.count <= 1 }
        return chat.title == "\(workspace.name) AI" || chat.sortedMessages.count <= 1
    }

    private static func title(for text: String) -> String {
        let line = text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? text
        let title = String(line.prefix(56)).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "New Chat" : title
    }

    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "clipcanvas" else {
            return .systemAction
        }
        guard let route = AppRouteService.route(from: url) else {
            return .discarded
        }

        switch route {
        case .object(let id):
            if canvasObjects.contains(where: { $0.id == id }) {
                AppRouteService.open(route)
                close()
                return .handled
            }
        case .clip(let id):
            if clips.contains(where: { $0.id == id }) {
                AppRouteService.open(route)
                close()
                return .handled
            }
        case .chat(let id):
            if let linked = chats.first(where: { $0.id == id }), linked.id != chat.id {
                linkedChat = linked
                return .handled
            }
        case .workspace(let id):
            if let workspace = workspaces.first(where: { $0.id == id }) {
                WorkspaceActionService.activate(workspace, among: workspaces)
                AppRouteService.open(route)
                close()
                return .handled
            }
        }
        return .discarded
    }

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }
}

#if canImport(UIKit)
private struct AIChatGrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, calculatedHeight: $calculatedHeight)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.textView = textView
        context.coordinator.recalculateHeight()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = .preferredFont(forTextStyle: .body)
        context.coordinator.recalculateHeight()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var calculatedHeight: CGFloat
        weak var textView: UITextView?

        init(text: Binding<String>, calculatedHeight: Binding<CGFloat>) {
            _text = text
            _calculatedHeight = calculatedHeight
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            recalculateHeight()
        }

        func recalculateHeight() {
            guard let textView else { return }
            let width = max(textView.bounds.width, 1)
            let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            let next = size.height.clamped(to: 22...118)
            guard abs(calculatedHeight - next) > 0.5 else { return }
            DispatchQueue.main.async { [weak self] in
                self?.calculatedHeight = next
            }
        }
    }
}
#else
private struct AIChatGrowingTextView: View {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onChange(of: text) { _, value in
                let lines = max(value.components(separatedBy: .newlines).count, 1)
                calculatedHeight = CGFloat(lines * 22).clamped(to: 22...118)
            }
    }
}
#endif

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
            } else if message.status == .streaming {
                HStack {
                    AIChatThinkingBubble()
                    Spacer(minLength: 44)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    if !isUser { Spacer(minLength: 44) }
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: message.sortedToolEvents.count)
        .animation(.easeInOut(duration: 0.18), value: message.statusRaw)
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

private struct AIChatThinkingBubble: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text("Working")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Color.adaptive(light: PlatformColor.secondarySystemBackground, dark: PlatformColor.secondarySystemBackground)
                .opacity(0.92),
            in: UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 18,
                    bottomLeading: 4,
                    bottomTrailing: 16,
                    topTrailing: 18
                ),
                style: .continuous
            )
        )
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
