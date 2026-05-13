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
                    ClipInfoPanel(clip: clip)
                }
                .appListItemRowInsets(vertical: 4)

                Section {
                    contentEditor
                        .appListCard(tint: clip.primaryDisplayColor, opacity: 0.16)
                }
                .appListItemRowInsets(vertical: 4)

                Section {
                    actionRows
                }
                .appListItemRowInsets(vertical: 4)

                Section("Tags") {
                    ClipTagEditor(clips: [clip])
                        .appListItemRowInsets(vertical: 4)
                }
            }
            .navigationTitle("Clip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitEdit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel("Done")
                }
            }
            .onAppear { editedContent = clip.content }
        }
    }

    private var contentEditor: some View {
        TextEditor(text: $editedContent)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 150)
            .focused($contentFocused)
    }

    private var actionRows: some View {
        Group {
            Button {
                ClipActionService.copy(clip)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if ClipActionService.openableURL(for: clip) != nil {
                Button {
                    ClipActionService.openURL(for: clip)
                } label: {
                    Label("Open Link", systemImage: "safari")
                }
            }

            Button {
                ClipActionService.togglePin(clip)
            } label: {
                Label(clip.isPinned ? "Unpin" : "Pin", systemImage: clip.isPinned ? "pin.slash" : "pin")
            }

            Button(role: .destructive) {
                ClipActionService.softDelete(clip)
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func commitEdit() {
        let trimmed = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != clip.content {
            clip.content = trimmed
            clip.type = Clip.detect(content: trimmed, imageData: clip.imageData)
            clip.sensitivity = ClipClassificationService.detectSensitivity(trimmed)
            clip.updatedAt = Date()
        }
    }
}

private struct ClipInfoPanel: View {
    let clip: Clip

    var body: some View {
        VStack(spacing: 10) {
            infoRow("Type", value: ClipTag.builtInName(for: clip.type), icon: clip.type.icon)
            Divider()
            infoRow("From", value: clip.origin.label, icon: "tray")
            Divider()
            LabeledContent {
                RelativeAgeText(date: clip.updatedAt, prefix: "Updated ", suffix: " ago", emptyText: "Updated just now")
                    .foregroundStyle(.primary)
            } label: {
                Label("Last Updated", systemImage: "clock")
                    .foregroundStyle(.primary.opacity(0.68))
            }
            Divider()
            infoRow("Created", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
        }
        .font(.subheadline)
    }

    private func infoRow(_ title: String, value: String, icon: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.primary)
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary.opacity(0.68))
        }
    }
}
