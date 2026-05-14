import SwiftUI

struct ClipDetailSheet: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss
    @State private var isTransforming = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ClipDetailActionToolbar(
                        isPinned: clip.isPinned,
                        canOpenLink: ClipActionService.openableURL(for: clip) != nil,
                        canTransform: clip.type != .image,
                        isTransforming: isTransforming,
                        onCopy: { ClipActionService.copy(clip) },
                        onOpen: { ClipActionService.openURL(for: clip) },
                        onPin: { ClipActionService.togglePin(clip) },
                        onTransform: applyTransform,
                        onDelete: {
                            ClipActionService.softDelete(clip)
                            dismiss()
                        }
                    )

                    ClipDetailSection("Info") {
                        ClipInfoPanel(clip: clip)
                    }

                    ClipDetailSection("Tags") {
                        ClipTagEditor(clips: [clip], composerShowsShadow: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
            .navigationTitle("Note Details")
            .appInlineNavigationTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCircleButton(systemImage: "xmark", size: 36, symbolSize: 14) {
                        dismiss()
                    }
                    .accessibilityLabel("Close")
                }
            }
            .appScrollDismissesKeyboardInteractively()
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
        .padding(16)
        .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
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
        .font(.body)
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
        .font(.body)
    }
}

private struct ClipDetailActionToolbar: View {
    let isPinned: Bool
    let canOpenLink: Bool
    let canTransform: Bool
    let isTransforming: Bool
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onPin: () -> Void
    let onTransform: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            action("Copy", icon: "doc.on.doc", action: onCopy)
            if canOpenLink {
                action("Open", icon: "safari", action: onOpen)
            }
            transformMenu
            action(isPinned ? "Unpin" : "Pin", icon: isPinned ? "pin.slash" : "pin", action: onPin)
            action("Delete", icon: "trash", destructive: true, action: onDelete)
        }
        .padding(8)
        .background {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 26))
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var transformMenu: some View {
        Menu {
            Button("Clean Up") { onTransform("clip.cleanUp") }
            Button("Distill") { onTransform("clip.distill") }
            Button("Action Items") { onTransform("clip.actionItems") }
            Button("Rewrite") { onTransform("clip.rewrite") }
            Button("Title") { onTransform("clip.title") }
        } label: {
            VStack(spacing: 5) {
                if isTransforming {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text("Transform")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canTransform || isTransforming)
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
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension ClipDetailSheet {
    func applyTransform(_ skillID: String) {
        guard !isTransforming, clip.type != .image else { return }
        let input = TransformSkillInput(
            clipIDs: [clip.id],
            text: clip.content
        )
        isTransforming = true
        Task {
            defer { isTransforming = false }
            do {
                let result = try await TransformSkillRegistry().run(skillID, input: input)
                guard let text = result.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { return }
                let classification = ClipClassificationService.classifySensitivity(text)
                clip.content = text
                clip.type = Clip.detect(content: text, imageData: clip.imageData)
                clip.updateSensitivity(classification.sensitivity, reason: classification.reason)
                clip.updatedAt = Date()
            } catch {
                // Keep the existing clip unchanged when a transform fails.
            }
        }
    }
}
