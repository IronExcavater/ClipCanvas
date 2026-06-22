import SwiftUI
import SwiftData

struct ClipRow: View {
    let clip: Clip
    let compact: Bool
    var isSelecting = false
    var isSelected = false
    var isExpanded = false
    var onSelect: (() -> Void)?
    var onDetails: (() -> Void)?
    var onPrimaryAction: (() -> Void)?

    @ObservedObject private var revealStore = SensitiveTextRevealStore.shared

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    var body: some View {
        ItemRow(tint: primaryTagColor, opacity: 0.025, isSelecting: isSelecting, isSelected: isSelected, dragID: clip.id.uuidString) {
            AppListRowHeader(
                systemImage: clip.type.icon,
                color: primaryTagColor,
                title: displayTitle,
                subtitle: compact || isExpanded ? nil : displayPreview,
                metadata: rowMetadata,
                lineLimit: compact ? 1 : 2,
                pinned: clip.isPinned,
                date: clip.updatedAt,
                dateSuffix: " ago"
            )
            if isExpanded {
                MarkdownPreview(
                    text: displayPreview,
                    revealedSensitiveParts: revealStore.revealedPartIDs,
                    onSensitivePartTapped: revealStore.toggle
                )
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.78))
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            rowFooter
        }
        .onTapGesture(perform: primaryAction)
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .leading) {
            AppSwipeIconButton(
                systemImage: clip.isPinned ? "pin.slash" : "pin",
                tint: .orange,
                accessibilityLabel: clip.isPinned ? "Unpin" : "Pin"
            ) {
                ClipActionService.togglePin(clip)
            }
        }
        .swipeActions(edge: .trailing) {
            AppSwipeIconButton(systemImage: "trash", role: .destructive, accessibilityLabel: "Delete") {
                ClipActionService.softDelete(clip)
            }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { ClipActionService.copy(clip) }
            if ClipActionService.openableURL(for: clip) != nil {
                Button("Open Link", systemImage: "safari") { ClipActionService.openURL(for: clip) }
            }
            Button(clip.isPrivateContent ? "Unmark Sensitive" : "Mark Sensitive",
                   systemImage: clip.isPrivateContent ? "lock.open" : "lock") {
                ClipActionService.toggleSensitive(clip)
            }
            Button("Add to Canvas", systemImage: "square.and.arrow.down") { addToCanvas() }
                .disabled(activeWorkspace == nil)
            Button(clip.isPinned ? "Unpin" : "Pin",
                   systemImage: clip.isPinned ? "pin.slash" : "pin") { ClipActionService.togglePin(clip) }
            if let onDetails {
                Button("Details", systemImage: "info.circle", action: onDetails)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { ClipActionService.softDelete(clip) }
        }
    }

    // MARK: - Private

    private func primaryAction() {
        if isSelecting { onSelect?() }
        else if let onPrimaryAction { onPrimaryAction() }
        else { ClipActionService.copy(clip) }
    }

    private var primaryTagColor: Color { clip.primaryDisplayColor }
    private var activeWorkspace: Workspace? { workspaces.first(where: \.isActive) ?? workspaces.first }
    private var displayPreview: String { clip.displayPreview(isRevealed: false) }
    private var displayTitle: String {
        displayPreview
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? ClipTag.builtInName(for: clip.type)
    }
    private func addToCanvas() { activeWorkspace?.place(clip: clip) }

    private var rowMetadata: [AppListRowMetadata] {
        var metadata = [
            AppListRowMetadata(clip.type.icon, value: ClipTag.builtInName(for: clip.type)),
            AppListRowMetadata("character.cursor.ibeam", value: "\(clip.content.count)", monospaced: true)
        ]
        if clip.isPrivateContent {
            metadata.append(AppListRowMetadata("lock.fill", value: "Sensitive"))
        }
        return metadata
    }

    private var rowFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            TagPillRow(tags: Array(clip.tags), limit: 3, size: compact ? .compact : .regular)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
