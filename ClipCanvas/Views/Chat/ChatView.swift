import SwiftData
import SwiftUI

struct WorkspaceChatPanel: View {
    let workspace: Workspace
    let contextCards: [WorkspaceCard]
    @Binding var extraContext: [String]
    let insertReply: (String) -> Void
    let close: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("openAIKey") private var openAIKey = ""
    @State private var thread: WorkspaceChatThread?
    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var contextText: String {
        let cardText = contextCards.compactMap { $0.snippet?.text }
        return (cardText + extraContext)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    private var messages: [WorkspaceChatMessage] {
        thread?.sortedMessages.filter { $0.role != .system } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            MessageList(messages: messages, isSending: isSending, insertReply: insertReply)
            Divider()
            ChatInputBar(text: $inputText, isSending: isSending, send: send)
        }
        .dropDestination(for: String.self) { items, _ in
            extraContext.append(contentsOf: items.filter { !$0.isEmpty })
            ensureThread()
            return true
        }
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
        .alert("Chat Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Workspace Chat", systemImage: "sparkles")
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

    // MARK: Actions

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

// MARK: - Message list

private struct MessageList: View {
    let messages: [WorkspaceChatMessage]
    let isSending: Bool
    let insertReply: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty && !isSending {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("Ask about your canvas cards,\ndrop text to add context.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    }
                    ForEach(messages) { message in
                        ChatBubble(message: message, insertReply: insertReply)
                            .id(message.id)
                    }
                    if isSending {
                        TypingIndicator()
                            .id("typing-indicator")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(14)
                .animation(.easeInOut(duration: 0.2), value: isSending)
            }
            .onChange(of: messages.count) { _, _ in
                if let id = messages.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .onChange(of: isSending) { _, sending in
                if sending {
                    withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
                }
            }
        }
    }
}

// MARK: - Typing indicator (three bouncing dots)

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 8, height: 8)
                        .offset(y: animating ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.clipCanvasSecondaryBackground, in: RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 48)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Chat bubble

private struct ChatBubble: View {
    let message: WorkspaceChatMessage
    let insertReply: (String) -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 36) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? Color.accentColor : Color.clipCanvasSecondaryBackground,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .foregroundStyle(isUser ? .white : .primary)
                if !isUser {
                    Button {
                        insertReply(message.content)
                    } label: {
                        Label("Add to Canvas", systemImage: "plus.square")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .padding(.leading, 4)
                }
            }
            if !isUser { Spacer(minLength: 36) }
        }
    }
}

// MARK: - Input bar

private struct ChatInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let send: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask, rewrite, compare…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clipCanvasInputBackground, in: RoundedRectangle(cornerRadius: 10))
                .disabled(isSending)
                .onSubmit { if !isSending { send() } }

            Button(action: send) {
                ZStack {
                    Circle()
                        .fill(canSend ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 34, height: 34)
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: isSending)
        }
        .padding(12)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
}
