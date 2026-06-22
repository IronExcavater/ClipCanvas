import SwiftUI
import SwiftData

/// A list row that represents a single AI chat session — used in the Sidebar.
struct AIChatPreviewRow: View {
    let chat: AIChat
    let onOpen: () -> Void

    var body: some View {
        ItemRow(tint: AIChatListRowStyle.statusTint(for: chat), opacity: 0.03) {
            AIChatListRowHeader(chat: chat)
        }
        .onTapGesture(perform: onOpen)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            AppSwipeIconButton(systemImage: "trash", role: .destructive, accessibilityLabel: "Delete") {
                chat.softDelete()
            }
        }
        .contextMenu {
            AIChatModeMenu(chat: chat)
            Button("Delete", systemImage: "trash", role: .destructive) { chat.softDelete() }
        }
    }
}

struct AIChatListRowHeader: View {
    let chat: AIChat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppListRowHeader(
                systemImage: AIChatListRowStyle.statusIcon(for: chat),
                color: AIChatListRowStyle.statusTint(for: chat),
                title: chat.title,
                subtitle: AIChatListRowStyle.description(for: chat),
                metadata: [
                    AppListRowMetadata("bubble.left.fill", value: "\(chat.sortedMessages.count)", monospaced: true),
                    AppListRowMetadata("square.on.square", value: "\(AIChatListRowStyle.attachmentCount(for: chat))", monospaced: true),
                    AppListRowMetadata(chat.mode.systemImage, value: chat.mode.displayName)
                ],
                date: chat.updatedAt,
                dateSuffix: " ago"
            )

            if AIChatListRowStyle.isWorking(chat) {
                ProgressView()
                    .controlSize(.mini)
                    .padding(6)
                    .background(.thinMaterial, in: Circle())
                    .transition(.opacity.combined(with: .scale(scale: 0.86)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: AIChatListRowStyle.isWorking(chat))
    }
}

struct AIChatModeMenu: View {
    let chat: AIChat

    var body: some View {
        Menu("Mode", systemImage: chat.mode.systemImage) {
            ForEach(AIChatMode.allCases, id: \.self) { mode in
                Button {
                    chat.setMode(mode)
                } label: {
                    Label(mode.displayName, systemImage: chat.mode == mode ? "checkmark" : mode.systemImage)
                }
            }
        }
    }
}

enum AIChatListRowStyle {
    static func isWorking(_ chat: AIChat) -> Bool {
        if chat.lastMessage?.status == .streaming { return true }
        let event = latestToolEvent(for: chat)
        return event?.status == .running || event?.status == .queued
    }

    static func statusIcon(for chat: AIChat) -> String {
        let event = latestToolEvent(for: chat)
        if event?.status == .running || event?.status == .queued { return "waveform" }
        if event?.status == .failed { return "exclamationmark" }
        if chat.lastMessage?.status == .streaming { return "sparkles" }
        return "sparkles"
    }

    static func statusTint(for chat: AIChat) -> Color {
        let event = latestToolEvent(for: chat)
        if event?.status == .failed { return .red }
        if event?.status == .running || event?.status == .queued { return .orange }
        return .accentColor
    }

    static func description(for chat: AIChat) -> String {
        if let event = latestToolEvent(for: chat) {
            return event.summary
        }
        return chat.preview
    }

    static func attachmentCount(for chat: AIChat) -> Int {
        chat.sortedMessages.reduce(0) { $0 + $1.attachments.count }
    }

    private static func latestToolEvent(for chat: AIChat) -> AIToolEvent? {
        chat.sortedMessages.flatMap(\.sortedToolEvents).last
    }
}
