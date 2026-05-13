import SwiftUI

struct ClipDetailSheet: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    @State private var editedContent = ""
    @FocusState private var contentFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Info") {
                    ClipInfoRow("Type", value: ClipTag.builtInName(for: clip.type), icon: clip.type.icon)
                    ClipInfoRow("From", value: clip.origin.label, icon: "tray")
                    ClipUpdatedRow(date: clip.updatedAt)
                    ClipInfoRow("Created", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
                }

                Section("Content") {
                    contentEditor
                        .appListCard(tint: clip.primaryDisplayColor, opacity: 0.16)
                }
                .appListItemRowInsets(vertical: 4)

                Section("Actions") {
                    ClipDetailActionToolbar(
                        isPinned: clip.isPinned,
                        canOpenLink: ClipActionService.openableURL(for: clip) != nil,
                        onCopy: { ClipActionService.copy(clip) },
                        onOpen: { ClipActionService.openURL(for: clip) },
                        onPin: { ClipActionService.togglePin(clip) },
                        onDelete: {
                            ClipActionService.softDelete(clip)
                            dismiss()
                        }
                    )
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        commitEdit()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel("Done")
                }
            }
            .onAppear { editedContent = clip.content }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.bottom, 72)
        }
    }

    private var contentEditor: some View {
        TextEditor(text: $editedContent)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 150)
            .focused($contentFocused)
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

private struct ClipInfoRow: View {
    let title: String
    let value: String
    let icon: String

    init(_ title: String, value: String, icon: String) {
        self.title = title
        self.value = value
        self.icon = icon
    }

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.primary)
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary.opacity(0.68))
        }
        .font(.subheadline)
    }
}

private struct ClipUpdatedRow: View {
    let date: Date

    var body: some View {
        LabeledContent {
            RelativeAgeText(date: date, prefix: "Updated ", suffix: " ago", emptyText: "Updated just now")
                .foregroundStyle(.primary)
        } label: {
            Label("Last Updated", systemImage: "clock")
                .foregroundStyle(.primary.opacity(0.68))
        }
        .font(.subheadline)
    }
}

private struct ClipDetailActionToolbar: View {
    let isPinned: Bool
    let canOpenLink: Bool
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            action("Copy", icon: "doc.on.doc", action: onCopy)
            if canOpenLink {
                action("Open", icon: "safari", action: onOpen)
            }
            action(isPinned ? "Unpin" : "Pin", icon: isPinned ? "pin.slash" : "pin", action: onPin)
            action("Delete", icon: "trash", destructive: true, action: onDelete)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func action(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(destructive ? .red : .primary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
