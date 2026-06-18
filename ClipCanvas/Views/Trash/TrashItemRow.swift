import SwiftUI

struct TrashItemRow: View {
    let title: String
    let systemImage: String
    let deletedAt: Date?
    let tint: Color
    var tags: [ClipTag] = []
    var dragID: String? = nil
    var isSelecting = false
    var isSelected = false
    let onTap: () -> Void
    let onRestore: () -> Void
    let onDeleteForever: () -> Void
    var onAddToCanvas: (() -> Void)? = nil

    var body: some View {
        ItemRow(tint: tint, opacity: 0.025, isSelecting: isSelecting, isSelected: isSelected, dragID: dragID) {
            AppListRowHeader(
                systemImage: systemImage,
                color: tint,
                title: title,
                metadata: [AppListRowMetadata("trash", value: "Deleted")],
                date: deletedAt,
                dateSuffix: "",
                datePrefix: "Deleted ",
                dateEmptyText: "Just now"
            )
            TagPillRow(tags: tags, limit: 2)
        }
        .onTapGesture { if isSelecting { onTap() } }
        .swipeActions(edge: .leading) {
            Button(action: onRestore) { Image(systemName: "arrow.counterclockwise") }
                .tint(.green)
                .accessibilityLabel("Restore")
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDeleteForever) { Image(systemName: "trash") }
                .accessibilityLabel("Delete Forever")
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
}
