import SwiftData
import SwiftUI

struct WorkspaceChatPanel: View {
    let workspace: Workspace
    let contextCards: [WorkspaceCard]
    // @Binding creates a two-way connection — changes here also update the parent's droppedChatContext.
    @Binding var extraContext: [String]
    let insertReply: (String) -> Void
    let close: () -> Void

    @Environment(\.modelContext) private var modelContext
    // @AppStorage is a property wrapper that reads/writes to UserDefaults and re-renders on change.
    @AppStorage("openAIKey") private var openAIKey = ""
    @State private var thread: WorkspaceChatThread?
    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var contextText: String {
        // Combine card text and any dropped items into a single context string.
        // A single filter handles both sources consistently.
        let cardText = contextCards.compactMap { $0.snippet?.text }
        return (cardText + extraContext)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    private var messages: [WorkspaceChatMessage] {
        // Filter out .system messages — those are only used to prime the model, not shown to users.
        thread?.sortedMessages.filter { $0.role != .system } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            MessageList(messages: messages, insertReply: insertReply)
            Divider()
            ChatInputBar(text: $inputText, isSending: isSending, send: send)
        }
        // dropDestination makes this view a valid drag-and-drop target for plain strings.
        .dropDestination(for: String.self) { items, _ in
            extraContext.append(contentsOf: items.filter { !$0.isEmpty })
            ensureThread()
            return true
        }
        // A second dropDestination handles SnippetDragPayload (ClipCanvas's custom drag type).
        .dropDestination(for: SnippetDragPayload.self) { items, _ in
            let dropped = items.compactMap { payload -> String? in
                let text = payload.imageData != nil
                    ? (payload.text.isEmpty ? "Dropped image from ClipCanvas" : payload.text)
                    : payload.text
                return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
            }
            extraContext.append(contentsOf: dropped)
            ensureThread()
            return !dropped.isEmpty
        }
        .task { ensureThread() }
        // Binding(get:set:) manually creates a Binding from arbitrary state — used here
        // because `.alert(isPresented:)` needs a Bool Binding but we track state as String?.
        .alert("Chat Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Workspace Chat", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Label("\(contextCards.count) card\(contextCards.count == 1 ? "" : "s")", systemImage: "paperclip")
                if !extraContext.isEmpty {
                    Label("\(extraContext.count) dropped", systemImage: "arrow.down.doc")
                }
                Spacer()
                if !extraContext.isEmpty {
                    Button(action: { extraContext.removeAll() }) {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear dropped context")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private func ensureThread() {
        guard thread == nil else { return }
        let newThread = WorkspaceChatThread(
            title: "Workspace chat",
            workspace: workspace,
            relatedCardIDs: contextCards.map(\.id),
            relatedTransformRunIDs: contextCards.compactMap { $0.transformRun?.id }
        )
        modelContext.insert(newThread)
        workspace.chatThreads.append(newThread)
        thread = newThread
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard !openAIKey.isEmpty else {
            errorMessage = "Add your OpenAI API key in Settings first."
            return
        }
        ensureThread()
        guard let thread else { return }

        inputText = ""
        isSending = true

        let userMessage = WorkspaceChatMessage(role: .user, content: text)
        userMessage.thread = thread
        thread.messages.append(userMessage)
        thread.relatedCardIDs = Array(Set(thread.relatedCardIDs + contextCards.map(\.id)))
        thread.updatedAt = Date()
        modelContext.insert(userMessage)

        // Pass previous messages as conversation history so the model has context.
        // Drop the last message (the one we just added) since it's the current prompt.
        let history = messages.dropLast().map { msg in
            (role: msg.role == .user ? "user" : "assistant", content: msg.content)
        }

        Task {
            do {
                let response = try await OpenAIService.chat(
                    userPrompt: text,
                    context: contextText,
                    history: history,
                    apiKey: openAIKey
                )
                let reply = WorkspaceChatMessage(role: .reply, content: response)
                reply.thread = thread
                thread.messages.append(reply)
                thread.updatedAt = Date()
                modelContext.insert(reply)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

private struct MessageList: View {
    let messages: [WorkspaceChatMessage]
    let insertReply: (String) -> Void

    var body: some View {
        // ScrollViewReader gives programmatic scroll control via proxy.scrollTo(_:anchor:).
        ScrollViewReader { proxy in
            ScrollView {
                // LazyVStack only creates views as they scroll into frame — like React virtualisation.
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 140)
                    }
                    ForEach(messages) { message in
                        ChatBubble(message: message, insertReply: insertReply)
                            .id(message.id)     // id lets ScrollViewReader scroll to this view
                    }
                }
                .padding(14)
            }
            .onChange(of: messages.count) { _, _ in
                if let id = messages.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }
}

private struct ChatBubble: View {
    let message: WorkspaceChatMessage
    let insertReply: (String) -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 8) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)    // lets users copy text with long-press
                if !isUser {
                    Button {
                        insertReply(message.content)
                    } label: {
                        Label("Add to Canvas", systemImage: "plus.square")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isUser ? Color.accentColor : Color.clipCanvasSecondaryBackground,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 36) }
        }
    }
}

private struct ChatInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let send: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // axis: .vertical makes the TextField grow vertically up to lineLimit rows.
            TextField("Ask, rewrite, compare...", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clipCanvasInputBackground, in: RoundedRectangle(cornerRadius: 10))
                .disabled(isSending)
            Button(action: send) {
                Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(12)
    }
}
