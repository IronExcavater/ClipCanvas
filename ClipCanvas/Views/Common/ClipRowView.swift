import SwiftUI
import SwiftData

struct ClipRowView: View {
    let clip: Clip
    let compact: Bool
    var isSelecting = false
    var isSelected = false
    var onSelect: (() -> Void)?
    var onDetails: (() -> Void)?

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    var body: some View {
        AppListItemButton(tint: primaryTagColor, opacity: 0.20, action: primaryAction) {
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
            .frame(minHeight: compact ? 46 : 58)
            .appListItemContentPadding(horizontal: 8, vertical: compact ? 6 : 7)
        }
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .draggable(clip.id.uuidString)
        .swipeActions(edge: .leading) {
            Button(action: { ClipActionService.togglePin(clip) }) {
                Label(clip.isPinned ? "Unpin" : "Pin",
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

    private func addToCanvas() {
        activeWorkspace?.place(clip: clip)
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
