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
                        AppCircleIconLabel(systemImage: "xmark", size: 36, symbolSize: 14)
                    }
                    .buttonStyle(BlendedIconButtonStyle(size: 36))
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var chatHeader: some View {
        HStack(spacing: 8) {
            Label(chat.workspace?.name ?? "No workspace", systemImage: "rectangle.3.group")
            Spacer()
            Text(AIModelPresetService.preset(for: chat.mode).model)
                .monospaced()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

            Menu {
                Button { setMode(.quick) } label: {
                    Label("Quick", systemImage: "bolt.fill")
                }
                Button { setMode(.thinking) } label: {
                    Label("Thinking", systemImage: "brain")
                }
            } label: {
                Image(systemName: chat.mode == .quick ? "bolt.fill" : "brain")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)

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
    private var hasVisibleContent: Bool {
        !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.sortedToolEvents.isEmpty
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if hasVisibleContent {
                HStack {
                    if isUser { Spacer(minLength: 44) }
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(isUser ? .white : .primary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            isUser ? Color.accentColor : Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
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
        .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground).opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
