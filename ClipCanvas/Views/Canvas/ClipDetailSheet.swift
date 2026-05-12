import SwiftUI

struct ClipDetailSheet: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    @State private var editedContent = ""
    @FocusState private var contentFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $editedContent)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                        .focused($contentFocused)
                } header: {
                    Text("Content")
                } footer: {
                    Text("\(editedContent.count) characters")
                }

                Section("Info") {
                    infoRow("Type", icon: clip.type.icon, value: ClipTag.builtInName(for: clip.type))
                    infoRow("Origin", icon: "tray", value: clip.origin.label)
                    infoRow("Status", icon: clip.isPinned ? "pin.fill" : "pin", value: clip.isPinned ? "Pinned" : "Not pinned")
                    infoRow("Created", icon: "calendar", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                    infoRow("Updated", icon: "clock", value: RelativeAgeFormatter.shortString(since: clip.updatedAt))
                }

                Section("Tags") {
                    tagRow(name: ClipTag.builtInName(for: clip.type), color: ClipTag.builtInColor(for: clip.type), detail: "Built in")
                    ForEach(clip.tags.sorted { $0.sortIndex < $1.sortIndex }) { tag in
                        tagRow(name: tag.name, color: tag.color, detail: "Custom")
                    }
                }

                Section("Actions") {
                    Button {
                        ClipboardService.write(clip: clip)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button {
                        clip.isPinned.toggle()
                        clip.updatedAt = Date()
                    } label: {
                        Label(clip.isPinned ? "Unpin from top" : "Keep at top", systemImage: clip.isPinned ? "pin.slash" : "pin")
                    }
                    Button(role: .destructive) {
                        clip.softDelete()
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Clip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(BlendedIconButtonStyle())
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        commitEdit()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(BlendedIconButtonStyle())
                    .accessibilityLabel("Done")
                }
            }
            .onAppear { editedContent = clip.content }
        }
    }

    private func tagRow(name: String, color: Color, detail: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 22, height: 22)
            Text(name)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(_ title: String, icon: String, value: String) -> some View {
        LabeledContent {
            Text(value.isEmpty ? "Now" : value)
                .foregroundStyle(.secondary)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private func commitEdit() {
        let trimmed = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != clip.content {
            clip.content = trimmed
            clip.updatedAt = Date()
        }
    }
}
