import SwiftUI

struct WorkspaceRowView: View {
    let workspace: Workspace
    let isRenaming: Bool
    @Binding var editingName: String
    let onActivate: () -> Void
    let onRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(workspace.isActive ? Color.accentColor : .secondary)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 3) {
                    if isRenaming {
                        TextField("Workspace name", text: $editingName)
                            .font(.subheadline.weight(.semibold))
                            .focused($focused)
                            .onSubmit(onCommitRename)
                            .onDisappear(perform: onCommitRename)
                    } else {
                        Text(workspace.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(metadata)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if workspace.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.yellow.opacity(workspace.isActive ? 0.24 : 0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(workspace.isActive ? Color.accentColor : Color.yellow.opacity(0.8))
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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
    }

    private var metadata: String {
        let count = workspace.placements.count
        let age = RelativeAgeFormatter.shortString(since: workspace.updatedAt)
        let cards = "\(count) card\(count == 1 ? "" : "s")"
        return age.isEmpty ? cards : "\(cards) - \(age)"
    }
}
