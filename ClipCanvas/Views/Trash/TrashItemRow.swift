import SwiftUI

struct TrashItemRow: View {
    let title: String
    var preview: String? = nil
    let systemImage: String
    let deletedAt: Date?
    let tint: Color
    var tags: [ClipTag] = []
    var imageData: Data? = nil
    var isExpanded = false
    var dragID: String? = nil
    var isSelecting = false
    var isSelected = false
    let onTap: () -> Void
    let onRestore: () -> Void
    let onDeleteForever: () -> Void
    var onAddToCanvas: (() -> Void)? = nil

    var body: some View {
        ItemRow(tint: tint, opacity: 0.025, isSelecting: isSelecting, isSelected: isSelected, dragID: dragID) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    imageThumbnail
                    AppListRowHeader(
                        systemImage: systemImage,
                        color: tint,
                        title: title,
                        subtitle: isExpanded ? nil : compactPreview,
                        metadata: [AppListRowMetadata("trash", value: "Deleted")],
                        lineLimit: 2,
                        date: deletedAt,
                        dateSuffix: "",
                        datePrefix: "Deleted ",
                        dateEmptyText: "Just now"
                    )
                }

                if isExpanded, let preview, !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MarkdownPreview(text: preview)
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.78))
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !tags.isEmpty {
                    TagPillRow(tags: tags, limit: 2)
                }
            }
        }
        .onTapGesture { if isSelecting { onTap() } }
        .swipeActions(edge: .leading) {
            AppSwipeIconButton(systemImage: "arrow.counterclockwise", tint: .green, accessibilityLabel: "Restore", action: onRestore)
        }
        .swipeActions(edge: .trailing) {
            AppSwipeIconButton(systemImage: "trash", role: .destructive, accessibilityLabel: "Delete Forever", action: onDeleteForever)
        }
        .contextMenu {
            if let onAddToCanvas {
                Button("Add to Canvas", systemImage: "square.and.arrow.down", action: onAddToCanvas)
            }
            Button("Restore", systemImage: "arrow.counterclockwise", action: onRestore)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDeleteForever)
        }
    }

    private var compactPreview: String? {
        guard let preview else { return nil }
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != title else { return nil }
        return trimmed
    }

    @ViewBuilder
    private var imageThumbnail: some View {
        if let imageData, let image = PlatformImage(data: imageData) {
            #if canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            #elseif canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            #endif
        }
    }
}
