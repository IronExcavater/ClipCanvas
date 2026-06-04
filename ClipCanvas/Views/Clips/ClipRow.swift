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

    @ObservedObject private var revealStore = PrivateClipRevealStore.shared

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    var body: some View {
        ItemRow(tint: primaryTagColor, isSelecting: isSelecting, isSelected: isSelected, dragID: clip.id.uuidString) {
            AppListRowHeader(
                systemImage: clip.type.icon,
                color: primaryTagColor,
                title: displayPreview,
                lineLimit: compact ? 1 : 2,
                pinned: clip.isPinned,
                date: clip.updatedAt,
                dateSuffix: " ago"
            )
            if isExpanded {
                Text(displayPreview)
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
            Button(action: { ClipActionService.togglePin(clip) }) {
                Image(systemName: clip.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
            .accessibilityLabel(clip.isPinned ? "Unpin" : "Pin")
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: { ClipActionService.softDelete(clip) }) {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete")
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { ClipActionService.copy(clip) }
            if ClipActionService.openableURL(for: clip) != nil {
                Button("Open Link", systemImage: "safari") { ClipActionService.openURL(for: clip) }
            }
            if clip.isPrivateContent {
                Button(isRevealed ? "Hide" : "Reveal",
                       systemImage: isRevealed ? "eye.slash" : "eye") { revealStore.toggle(clip) }
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
    private var isRevealed: Bool { revealStore.isRevealed(clip) }
    private var displayPreview: String { clip.displayPreview(isRevealed: isRevealed) }
    private func addToCanvas() { activeWorkspace?.place(clip: clip) }

    private var rowFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                clipStat(clip.type.icon, label: ClipTag.builtInName(for: clip.type))
                clipStat("character.cursor.ibeam", label: "\(clip.content.count)")
                if clip.isPrivateContent {
                    Button {
                        revealStore.toggle(clip)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(isRevealed ? "Hide" : "Reveal")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.primary.opacity(0.56))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "Hide sensitive content" : "Reveal sensitive content")
                }
            }
            .foregroundStyle(.primary.opacity(0.56))
            .padding(.top, 2)

            TagPillRow(tags: Array(clip.tags), limit: 3, size: compact ? .compact : .regular)
        }
    }

    private func clipStat(_ icon: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(label).font(.caption2.weight(.semibold))
        }
    }
}
