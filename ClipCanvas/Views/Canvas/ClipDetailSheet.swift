import SwiftUI
import UIKit

struct ClipDetailSheet: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    @State private var editedContent = ""
    @FocusState private var contentFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ClipDetailSection("Info") {
                        ClipInfoPanel(clip: clip)
                    }

                    ClipDetailSection("Content") {
                        contentEditor
                            .padding(12)
                            .frame(minHeight: 180)
                            .background {
                                ClipDetailContentBackground(tint: clip.primaryDisplayColor)
                            }
                    }

                    ClipDetailSection("Actions") {
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

                    ClipDetailSection("Tags") {
                        ClipTagEditor(clips: [clip])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 120)
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
                    .buttonStyle(BlendedIconButtonStyle(size: 36))
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        commitEdit()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(BlendedIconButtonStyle(size: 36))
                    .fontWeight(.semibold)
                    .accessibilityLabel("Done")
                }
            }
            .onAppear { editedContent = clip.content }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var contentEditor: some View {
        TextEditor(text: $editedContent)
            .font(.body)
            .scrollContentBackground(.hidden)
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

private struct ClipDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            content
        }
    }
}

private struct ClipInfoPanel: View {
    let clip: Clip

    var body: some View {
        VStack(spacing: 9) {
            ClipInfoRow("Type", value: ClipTag.builtInName(for: clip.type), icon: clip.type.icon)
            ClipInfoRow("From", value: clip.origin.label, icon: "tray")
            ClipUpdatedRow(date: clip.updatedAt)
            ClipInfoRow("Created", value: clip.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
        }
        .padding(12)
        .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

private struct ClipDetailContentBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.20))
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
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
        .padding(7)
        .background {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
            }
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
            .background(Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
