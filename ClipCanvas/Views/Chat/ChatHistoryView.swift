import SwiftData
import SwiftUI

struct ChatHistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkspaceChatThread.updatedAt, order: .reverse) private var threads: [WorkspaceChatThread]

    @State private var selectedThread: WorkspaceChatThread?

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty {
                    ContentUnavailableView(
                        "No chats yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a conversation from the canvas to see it here.")
                    )
                } else {
                    List {
                        ForEach(threads) { thread in
                            ChatThreadRow(thread: thread)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedThread = thread }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { delete(thread) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("AI Chats")
            .sheet(item: $selectedThread) { thread in
                ChatThreadDetailView(thread: thread)
            }
        }
    }

    private func delete(_ thread: WorkspaceChatThread) {
        modelContext.delete(thread)
    }
}

// MARK: - Thread row

private struct ChatThreadRow: View {
    let thread: WorkspaceChatThread

    private var lastMessage: WorkspaceChatMessage? {
        thread.sortedMessages.last(where: { $0.role != .system })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(thread.title.isEmpty ? "Untitled Chat" : thread.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(thread.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let preview = lastMessage?.content, !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let name = thread.workspace?.name {
                    Label(name, systemImage: "rectangle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                let count = thread.messages.filter { $0.role != .system }.count
                if count > 0 {
                    Label("\(count) message\(count == 1 ? "" : "s")", systemImage: "bubble.left")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Thread detail

private struct ChatThreadDetailView: View {
    let thread: WorkspaceChatThread
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(thread.sortedMessages.filter { $0.role != .system }) { message in
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            message.role == .user ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    Text(message.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle(thread.title.isEmpty ? "Chat" : thread.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
