import SwiftUI
import SwiftData

struct AIChatsPage: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<AIChat> { $0.deletedAt == nil },
        sort: \AIChat.updatedAt,
        order: .reverse
    ) private var chats: [AIChat]
    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @State private var search = ""
    @State private var chatSelection = SelectionState<UUID>()
    @State private var confirmingDelete = false
    @State private var activeChat: AIChat?
    @State private var renamingChat: AIChat?
    @State private var renameText = ""

    private var filteredChats: [AIChat] {
        search.isEmpty ? chats
                       : chats.filter { $0.title.localizedCaseInsensitiveContains(search)
                                       || $0.preview.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            AppSearchSelectionBar(
                search: $search.withListAnimation,
                prompt: "Search chats",
                isSelecting: chatSelection.isActive,
                selectedCount: chatSelection.count,
                onBeginSelection: { chatSelection.begin() },
                onEndSelection: { chatSelection.end() }
            ) {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    AppToolbarCircleLabel(systemImage: "trash", size: 40, symbolSize: 15)
                }
                .buttonStyle(.plain)
                .disabled(chatSelection.isEmpty)
            }
            .appListItemRowInsets(vertical: 4)

            if chats.isEmpty {
                AppListEmptyState(
                    isSourceEmpty: true,
                    searchText: search,
                    title: "No Chats Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: "No chat history."
                )
            } else if filteredChats.isEmpty {
                AppListEmptyState(
                    isSourceEmpty: false,
                    searchText: search,
                    title: "No Chats Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: "No chat history."
                )
            } else {
                ForEach(filteredChats) { chat in
                    AIChatRow(
                        chat: chat,
                        isRenaming: renamingChat?.id == chat.id,
                        editingTitle: $renameText,
                        isSelecting: chatSelection.isActive,
                        isSelected: chatSelection.contains(chat.id),
                        onTap: { handleTap(chat) },
                        onRename: { beginRename(chat) },
                        onCommitRename: { commitRename() },
                        onDelete: { chat.softDelete() }
                    )
                    .appListItemRowInsets(vertical: 3)
                }
            }
        }
        .appPageListStyle()
        .navigationTitle("AI Chats")
        .animation(.easeInOut(duration: 0.18), value: search.isEmpty)
        .overlay {
            if confirmingDelete {
                AppConfirmationOverlay(
                    title: "Delete selected chats?",
                    message: "The selected chats will move to Recently Deleted.",
                    destructiveTitle: "Delete",
                    onConfirm: {
                        deleteSelected()
                        confirmingDelete = false
                    },
                    onCancel: { confirmingDelete = false }
                )
            }
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
        Button(action: createChat) {
            AppCircleIconLabel(systemImage: "sparkles")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New Chat")
        .opacity(chatSelection.isActive ? 0 : 1)
        .disabled(chatSelection.isActive)
    }

    private func handleTap(_ chat: AIChat) {
        if chatSelection.isActive { chatSelection.toggle(chat.id) }
        else { activeChat = chat }
    }

    private func createChat() {
        search = ""
        chatSelection.end()
        activeChat = AIChatService.createChat(in: context, workspaces: workspaces)
    }

    private func beginRename(_ chat: AIChat) {
        renamingChat = chat
        renameText = chat.title
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
        chats.filter { chatSelection.contains($0.id) }.forEach { $0.softDelete() }
        chatSelection.end()
    }
}

private struct AIChatRow: View {
    let chat: AIChat
    let isRenaming: Bool
    @Binding var editingTitle: String
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        ItemRow(
            tint: AIChatListRowStyle.statusTint(for: chat),
            opacity: 0.035,
            isSelecting: isSelecting,
            isSelected: isSelected
        ) {
            if isRenaming {
                renameField
            } else {
                AIChatListRowHeader(chat: chat)
            }
        }
        .onTapGesture(perform: onTap)
        .onChange(of: isRenaming) { _, newValue in
            if newValue { focused = true }
        }
        .swipeActions(edge: .leading) {
            Button(action: onRename) { Image(systemName: "pencil") }
                .tint(.blue)
                .accessibilityLabel("Rename")
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .accessibilityLabel("Delete")
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: onRename)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var renameField: some View {
        TextField("Chat name", text: $editingTitle)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .submitLabel(.done)
            .focused($focused)
            .onSubmit(onCommitRename)
            .onDisappear(perform: onCommitRename)
            .frame(minHeight: 34)
    }
}
