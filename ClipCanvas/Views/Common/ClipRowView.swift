import SwiftUI

struct ClipRowView: View {
    let clip: Clip
    let compact: Bool
    var isSelecting = false
    var isSelected = false
    var onSelect: (() -> Void)?
    var onDetails: (() -> Void)?

    var body: some View {
        AppListItemButton(tint: primaryTagColor, opacity: 0.14, action: primaryAction) {
            HStack(alignment: .center, spacing: 8) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
                textContent
                Spacer(minLength: 4)
                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(primaryTagColor)
                        .accessibilityLabel("Pinned")
                    }
            }
            .appListItemContentPadding()
        }
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .draggable(clip.id.uuidString)
        .swipeActions(edge: .leading) {
            Button(action: { ClipActionService.togglePin(clip) }) {
                Label(clip.isPinned ? "Unpin from top" : "Keep at top",
                      systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: { ClipActionService.softDelete(clip) }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                ClipActionService.copy(clip)
            }
            if ClipActionService.openableURL(for: clip) != nil {
                Button("Open Link", systemImage: "safari") {
                    ClipActionService.openURL(for: clip)
                }
            }
            Button(clip.isPinned ? "Unpin from top" : "Keep at top",
                   systemImage: clip.isPinned ? "pin.slash" : "pin") {
                ClipActionService.togglePin(clip)
            }
            if let onDetails {
                Button("Details", systemImage: "info.circle", action: onDetails)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                ClipActionService.softDelete(clip)
            }
        }
    }

    private func primaryAction() {
        if isSelecting {
            onSelect?()
        } else {
            ClipActionService.copy(clip)
        }
    }

    private var primaryTagColor: Color {
        clip.primaryDisplayColor
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(clip.preview)
                .font(.subheadline.weight(.medium))
                .lineLimit(compact ? 1 : 2)
                .foregroundStyle(.primary)

            HStack(spacing: 5) {
                Text("From \(clip.origin.label)").font(.caption2)
                Spacer()
                RelativeAgeText(date: clip.updatedAt, prefix: "Updated ", suffix: " ago")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
