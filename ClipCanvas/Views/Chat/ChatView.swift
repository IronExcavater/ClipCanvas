import SwiftData
import SwiftUI

struct WorkspaceChatPanel: View {
    let workspace: Workspace
    let contextCards: [WorkspaceCard]
    @Binding var extraContext: [String]
    let insertReply: (String) -> Void
    let close: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var thread: WorkspaceChatThread?
    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var contextText: String {
        let cardText = contextCards
            .compactMap { $0.snippet?.text }
            .filter { !$0.isEmpty }
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
            MessageList(messages: messages, insertReply: insertReply)
            Divider()
            ChatInputBar(text: $inputText, isSending: isSending, send: send)
        }
        .dropDestination(for: String.self) { items, _ in
            extraContext.append(contentsOf: items.filter { !$0.isEmpty })
            ensureThread()
            return true
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
                    Button("Clear dropped") { extraContext.removeAll() }
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

        Task {
            let response = replyText(for: text)
            let reply = WorkspaceChatMessage(role: .reply, content: response)
            reply.thread = thread
            thread.messages.append(reply)
            thread.updatedAt = Date()
            modelContext.insert(reply)
            isSending = false
        }
    }

    private func replyText(for text: String) -> String {
        let trimmedContext = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContext.isEmpty else { return text }
        return [text, trimmedContext].joined(separator: "\n\n")
    }
}

private struct MessageList: View {
    let messages: [WorkspaceChatMessage]
    let insertReply: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        Text("Select cards or drag card text here, then ask.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 140)
                    }
                    ForEach(messages) { message in
                        ChatBubble(message: message, insertReply: insertReply)
                            .id(message.id)
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
                    .textSelection(.enabled)
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
                isUser ? Color.accentColor : Color(.secondarySystemGroupedBackground),
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
            TextField("Ask, rewrite, compare...", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
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
