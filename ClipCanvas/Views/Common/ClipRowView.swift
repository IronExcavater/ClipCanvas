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
        AppListItemContainer(tint: primaryTagColor, opacity: 0.20) {
            HStack(alignment: .top, spacing: 10) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.top, 2)
                }

                textContent

                if clip.isPrivateContent {
                    privateRevealButton
                        .padding(.top, -1)
                }

                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(primaryTagColor)
                        .accessibilityLabel("Pinned")
                    }
            }
            .frame(minHeight: compact ? 42 : (isExpanded ? 112 : 68))
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

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayPreview)
                .font(.subheadline.weight(.medium))
                .lineLimit(compact ? 1 : (isExpanded ? 8 : 3))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                Text(ClipTag.builtInName(for: clip.type)).font(.caption2)
                Spacer()
                RelativeAgeText(date: clip.updatedAt, prefix: "Updated ", suffix: " ago")
                    .font(.caption2)
            }
            .foregroundStyle(.primary.opacity(0.66))

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
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var privateRevealButton: some View {
        Button {
            revealStore.toggle(clip)
        } label: {
            Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.86), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Hide sensitive content" : "Reveal sensitive content")
    }
}
