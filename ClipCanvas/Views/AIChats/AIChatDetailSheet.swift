import SwiftData
import SwiftUI
import UIKit

struct AIChatDetailSheet: View {
    @Bindable var chat: AIChat

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var input = ""

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatHeader
                Divider()
                messageList
                Divider()
                inputBar
            }
            .navigationTitle(chat.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        AppCircleIconButtonLabel(systemImage: "xmark", size: 36, symbolSize: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: Binding(get: { chat.mode }, set: setMode)) {
                Text("Quick").tag(AIChatMode.quick)
                Text("Thinking").tag(AIChatMode.thinking)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Label(chat.workspace?.name ?? "No workspace", systemImage: "rectangle.3.group")
                Spacer()
                Text(AIModelPresetService.preset(for: chat.mode).model)
                    .monospaced()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if chat.sortedMessages.isEmpty {
                        ContentUnavailableView(
                            "Ask About This Workspace",
                            systemImage: "sparkles",
                            description: Text("Attach notes and canvas cards, then ask ClipCanvas AI to reason over them.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }

                    ForEach(chat.sortedMessages) { message in
                        AIChatMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
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
            TextField("Ask ClipCanvas AI", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
        .padding(14)
        .background(.regularMaterial)
    }

    private func setMode(_ mode: AIChatMode) {
        chat.mode = mode
        chat.updatedAt = Date()
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        input = ""
        if chat.title == "New Chat" {
            chat.title = String(trimmed.prefix(42))
        }

        let user = ChatMessage(role: .user, content: trimmed)
        user.chat = chat
        chat.messages.append(user)
        context.insert(user)

        let assistant = ChatMessage(
            role: .assistant,
            content: "AI streaming and workspace tools are being connected through the shared action layer."
        )
        assistant.chat = chat
        chat.messages.append(assistant)
        context.insert(assistant)
        chat.updatedAt = Date()
    }
}

private struct AIChatMessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 44) }
            Text(message.content)
                .font(.body)
                .foregroundStyle(isUser ? .white : .primary)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isUser ? Color.accentColor : Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isUser { Spacer(minLength: 44) }
        }
    }
}
