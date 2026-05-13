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
                    contentEditor
                        .appListItemContentPadding(horizontal: 10, vertical: 8)
                        .appListCard(tint: clip.primaryDisplayColor, opacity: 0.16)
                }
                .appListItemRowInsets(vertical: 4)

                Section {
                    actionStrip
                    metadataGrid
                }
                .appListItemRowInsets(vertical: 4)
                .buttonStyle(.plain)

                Section("Tags") {
                    ClipTagEditor(clips: [clip])
                        .appListItemRowInsets(vertical: 4)
                }
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

    private var contentEditor: some View {
        TextEditor(text: $editedContent)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 150)
            .focused($contentFocused)
    }

    private var actionStrip: some View {
        HStack(spacing: 10) {
            detailAction("Copy", icon: "doc.on.doc") {
                ClipActionService.copy(clip)
            }

            if ClipActionService.openableURL(for: clip) != nil {
                detailAction("Open", icon: "safari") {
                    ClipActionService.openURL(for: clip)
                }
            }

            detailAction(clip.isPinned ? "Pinned" : "Pin", icon: clip.isPinned ? "pin.fill" : "pin") {
                ClipActionService.togglePin(clip)
            }

            Spacer()

            Button(role: .destructive) {
                ClipActionService.softDelete(clip)
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.iconOnly)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    private var metadataGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(ClipTag.builtInName(for: clip.type), systemImage: clip.type.icon)
            Label(clip.origin.label, systemImage: "tray")
            Label {
                RelativeAgeText(date: clip.updatedAt, prefix: "Last updated ", emptyText: "Last updated just now")
            } icon: {
                Image(systemName: "clock")
            }
            Label(clip.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func detailAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(Color.secondary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
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
