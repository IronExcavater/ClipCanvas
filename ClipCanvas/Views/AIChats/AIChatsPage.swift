import SwiftUI
import SwiftData

struct AIChatsPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AIChat.updatedAt, order: .reverse) private var chats: [AIChat]
    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @State private var search = ""
    @State private var isSelecting = false
    @State private var selection = Set<UUID>()
    @State private var confirmingDelete = false
    @State private var searchPresented = false
    @State private var activeChat: AIChat?
    @State private var renamingChat: AIChat?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    private var filteredChats: [AIChat] {
        guard !search.isEmpty else { return chats }
        return chats.filter {
            $0.title.localizedCaseInsensitiveContains(search)
            || $0.preview.localizedCaseInsensitiveContains(search)
        }
    }

    private var selectedChats: [AIChat] {
        chats.filter { selection.contains($0.id) }
    }

    var body: some View {
        List {
            if chats.isEmpty {
                ContentUnavailableView(
                    "No Chats Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Chats will appear here when AI features are available.")
                )
                .appEmptyStateRow()
            } else if filteredChats.isEmpty {
                ContentUnavailableView.search(text: search)
                    .appEmptyStateRow()
            } else {
                ForEach(filteredChats) { chat in
                    AIChatRow(
                        chat: chat,
                        isSelecting: isSelecting,
                        isSelected: selection.contains(chat.id),
                        onTap: { handleTap(chat) },
                        onRename: { beginRename(chat) },
                        onDelete: { context.delete(chat) }
                    )
                    .appListItemRowInsets(vertical: 3)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .appSearchAwareNavigationTitle("AI Chats", isSearching: searchPresented)
        .searchable(text: $search, isPresented: $searchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
        .animation(.easeInOut(duration: 0.18), value: searchPresented)
        .alert("Delete selected chats?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteSelected)
        }
        .alert("Rename Chat", isPresented: $showRenameAlert) {
            TextField("Chat name", text: $renameText)
            Button("Save") { commitRename() }
            Button("Cancel", role: .cancel) { renamingChat = nil }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarActions
            }
        }
        .sheet(item: $activeChat) { chat in
            AIChatDetailSheet(chat: chat)
        }
    }

    @ViewBuilder
    private var toolbarActions: some View {
        if isSelecting {
            Text("\(selection.count)")
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 22)

            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                AppToolbarCircleLabel(systemImage: "trash", size: 36, symbolSize: 15)
            }
            .buttonStyle(.plain)
            .disabled(selection.isEmpty)

            Button(action: endSelection) {
                AppToolbarCircleLabel(systemImage: "checkmark", size: 36, symbolSize: 15)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: beginSelection) {
                AppToolbarCircleLabel(systemImage: "checklist", size: 36, symbolSize: 15)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select")
            .opacity(searchPresented ? 0 : 1)
            .disabled(searchPresented)

            AppToolbarCircleButton(systemImage: "plus", action: createChat)
                .accessibilityLabel("New Chat")
                .opacity(searchPresented ? 0 : 1)
                .disabled(searchPresented)
        }
    }

    private func handleTap(_ chat: AIChat) {
        if isSelecting {
            toggle(chat)
        } else {
            activeChat = chat
        }
    }

    private func toggle(_ chat: AIChat) {
        if selection.contains(chat.id) {
            selection.remove(chat.id)
        } else {
            selection.insert(chat.id)
        }
    }

    private func createChat() {
        search = ""
        searchPresented = false
        endSelection()
        activeChat = AIChatService.createChat(in: context, workspaces: workspaces)
    }

    private func beginRename(_ chat: AIChat) {
        renamingChat = chat
        renameText = chat.title
        showRenameAlert = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let chat = renamingChat {
            chat.title = trimmed
            chat.updatedAt = Date()
        }
        renamingChat = nil
    }

    private func deleteSelected() {
        selectedChats.forEach { context.delete($0) }
        endSelection()
    }

    private func beginSelection() {
        selection.removeAll()
        isSelecting = true
    }

    private func endSelection() {
        selection.removeAll()
        isSelecting = false
    }
}

private struct AIChatRow: View {
    let chat: AIChat
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(chat.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(chat.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                RelativeAgeText(date: chat.updatedAt, prefix: "Updated ", suffix: " ago")
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.66))
            }
        }
        .appListCard(tint: .secondary, opacity: 0.08)
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: onRename)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
