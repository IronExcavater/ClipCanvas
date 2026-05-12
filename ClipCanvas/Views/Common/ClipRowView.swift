import SwiftUI

struct ClipRowView: View {
    let clip: Clip
    let compact: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    var onDetails: (() -> Void)?

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: clip.type.icon)
                    .font(.system(size: compact ? 14 : 16, weight: .semibold))
                    .foregroundStyle(primaryTagColor)
                    .frame(width: 24, height: 24)
                textContent
                Spacer(minLength: 4)
                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(primaryTagColor)
                        .accessibilityLabel("Pinned")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, compact ? 10 : 12)
            .background(primaryTagColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(primaryTagColor)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .draggable(clip.id.uuidString)
        .swipeActions(edge: .leading) {
            Button(action: onTogglePin) {
                Label(clip.isPinned ? "Unpin from top" : "Keep at top",
                      systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc", action: onCopy)
            Button(clip.isPinned ? "Unpin from top" : "Keep at top",
                   systemImage: clip.isPinned ? "pin.slash" : "pin",
                   action: onTogglePin)
            if let onDetails {
                Button("Details", systemImage: "info.circle", action: onDetails)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var primaryTagColor: Color {
        clip.primaryDisplayColor
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text(clip.preview)
                .font(.subheadline)
                .lineLimit(compact ? 1 : 2)
                .foregroundStyle(.primary)

            if !compact {
                HStack(spacing: 5) {
                    Text(clip.primaryDisplayTagName).font(.caption2.weight(.medium))
                    Text(clip.origin.label).font(.caption2)
                    Spacer()
                    if !RelativeAgeFormatter.shortString(since: clip.updatedAt).isEmpty {
                        Text(RelativeAgeFormatter.shortString(since: clip.updatedAt)).font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}
