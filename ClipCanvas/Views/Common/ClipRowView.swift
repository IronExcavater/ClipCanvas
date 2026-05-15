import SwiftUI
import SwiftData

struct ClipRowView: View {
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
        AppListItemContainer(tint: primaryTagColor, opacity: 0.12) {
            HStack(alignment: .top, spacing: 10) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.top, 3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    rowHeader
                    if isExpanded {
                        expandedContent
                    }
                    rowFooter
                }
            }
        }
        .onTapGesture(perform: primaryAction)
        .accessibilityAddTraits(.isButton)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .draggable(clip.id.uuidString)
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
            Button("Copy", systemImage: "doc.on.doc") {
                ClipActionService.copy(clip)
            }
            if ClipActionService.openableURL(for: clip) != nil {
                Button("Open Link", systemImage: "safari") {
                    ClipActionService.openURL(for: clip)
                }
            }
            if clip.isPrivateContent {
                Button(isRevealed ? "Hide" : "Reveal",
                       systemImage: isRevealed ? "eye.slash" : "eye") {
                    revealStore.toggle(clip)
                }
            }
            Button(clip.isPrivateContent ? "Unmark Sensitive" : "Mark Sensitive",
                   systemImage: clip.isPrivateContent ? "lock.open" : "lock") {
                ClipActionService.toggleSensitive(clip)
            }
            Button("Add to Canvas", systemImage: "square.and.arrow.down") {
                addToCanvas()
            }
            .disabled(activeWorkspace == nil)
            Button(clip.isPinned ? "Unpin" : "Pin",
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
        } else if let onPrimaryAction {
            onPrimaryAction()
        } else {
            ClipActionService.copy(clip)
        }
    }

    private var primaryTagColor: Color {
        clip.primaryDisplayColor
    }

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var isRevealed: Bool {
        revealStore.isRevealed(clip)
    }

    private var displayPreview: String {
        clip.displayPreview(isRevealed: isRevealed)
    }

    private func addToCanvas() {
        activeWorkspace?.place(clip: clip)
    }

    private var rowHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: clip.type.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(primaryTagColor, in: Circle())

            Text(displayPreview)
                .font(.subheadline.weight(.medium))
                .lineLimit(compact ? 1 : 2)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(primaryTagColor)
            }

            RelativeAgeText(date: clip.updatedAt, suffix: " ago")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary.opacity(0.58))
        }
    }

    private var expandedContent: some View {
        Text(displayPreview)
            .font(.callout)
            .foregroundStyle(.primary.opacity(0.78))
            .lineLimit(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var rowFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                clipStat(clip.type.icon, label: ClipTag.builtInName(for: clip.type))
                clipStat("character.cursor.ibeam", label: "\(clip.content.count)")
                if clip.isPrivateContent {
                    privateRevealButton
                }
            }
            .foregroundStyle(.primary.opacity(0.56))
            .padding(.top, 2)

            if !clip.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(clip.tags.sorted { $0.sortIndex < $1.sortIndex }.prefix(3))) { tag in
                        AppTagPill(
                            title: tag.name,
                            color: tag.color,
                            icon: "tag",
                            isSelected: false,
                            size: compact ? .compact : .regular
                        )
                    }
                }
            }
        }
    }

    private func clipStat(_ icon: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
        }
    }

    private var privateRevealButton: some View {
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
