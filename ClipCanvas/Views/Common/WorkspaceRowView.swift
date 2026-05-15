import SwiftUI

struct WorkspaceRowView: View {
    let workspace: Workspace
    let isRenaming: Bool
    @Binding var editingName: String
    var isSelecting = false
    var isSelected = false
    let onActivate: () -> Void
    let onRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Bool

    private var cardCount: Int { workspace.canvasObjects.filter(\.isVisible).count }
    private var tint: Color { workspace.isActive ? Color.accentColor : Color.secondary }

    var body: some View {
        Button(action: onActivate) {
            HStack(alignment: .top, spacing: 10) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.top, 3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: workspace.isActive ? "checkmark" : "folder.fill")
                            .font(.system(size: workspace.isActive ? 11 : 12, weight: .bold))
                            .foregroundStyle(workspace.isActive ? .white : .primary.opacity(0.7))
                            .frame(width: 22, height: 22)
                            .background(workspace.isActive ? Color.accentColor : Color.primary.opacity(0.10), in: Circle())

                        nameContent

                        Spacer(minLength: 8)

                        RelativeAgeText(date: workspace.updatedAt, suffix: " ago")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.primary.opacity(0.58))
                    }

                    Text(cardCount == 0 ? "Empty canvas" : "\(cardCount) card\(cardCount == 1 ? "" : "s") on canvas")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.72))

                    HStack(spacing: 12) {
                        wsStat("square.grid.2x2", value: "\(cardCount)")
                        if workspace.isActive {
                            wsStat("dot.radiowaves.left.and.right", label: "Active")
                        }
                    }
                    .padding(.top, 4)
                    .foregroundStyle(.primary.opacity(0.56))
                }
            }
        }
        .appListCard(tint: tint, opacity: workspace.isActive ? 0.10 : 0.06)
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: onRename)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .onChange(of: isRenaming) { _, newValue in
            if newValue { focused = true }
        }
        .animation(.easeInOut(duration: 0.18), value: workspace.isActive)
    }

    @ViewBuilder
    private var nameContent: some View {
        if isRenaming {
            TextField("Workspace name", text: $editingName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .submitLabel(.done)
                .focused($focused)
                .onChange(of: editingName) { _, newValue in
                    let limited = WorkspaceNamePolicy.limitedEditingText(newValue)
                    if limited != newValue { editingName = limited }
                }
                .onSubmit(onCommitRename)
                .onDisappear(perform: onCommitRename)
        } else {
            Text(workspace.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private func wsStat(_ icon: String, value: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(value).font(.caption2.weight(.semibold).monospacedDigit())
        }
    }

    private func wsStat(_ icon: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(label).font(.caption2.weight(.semibold))
        }
    }
}
