import SwiftUI
import SwiftData

/// A list row that represents a single AI chat session — used in the Sidebar.
struct AIChatPreviewRow: View {
    @Environment(\.modelContext) private var context
    let chat: AIChat
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    AppIconBadge(
                        systemImage: chat.mode == .thinking ? "brain" : "bolt.fill",
                        color: Color.accentColor.opacity(0.14),
                        foreground: Color.accentColor
                    )
                    Text(chat.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(chat.preview)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.78))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    chatStat("\(chat.sortedMessages.count)", icon: "bubble.left.fill")
                    let attachCount = chat.sortedMessages.flatMap(\.sortedAttachments).count
                    chatStat("\(attachCount)", icon: "square.on.square")
                    chatStat(chat.mode == .thinking ? "Deep" : "Quick",
                             icon: chat.mode == .thinking ? "brain" : "bolt")
                    Spacer(minLength: 0)
                    RelativeAgeText(date: chat.updatedAt, suffix: " ago")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.52))
                }
                .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.78))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { context.delete(chat) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { context.delete(chat) }
        }
    }

    private func chatStat(_ value: String, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.primary.opacity(0.52))
    }
}
