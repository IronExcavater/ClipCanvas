import SwiftUI
import SwiftData

struct SettingsPage: View {
    @Environment(\.modelContext) private var context

    @AppStorage("settings.copyClipOnTap") private var copyClipOnTap = true

    @Query(sort: \ClipTag.sortIndex) private var tags: [ClipTag]

    @State private var newTagName = ""
    @State private var selectedColor = "#FF9800"

    private let colorPresets = ["#FF9800", "#4CAF50", "#2196F3", "#9C27B0", "#E91E63", "#607D8B"]
    private var userTags: [ClipTag] { tags.filter { !$0.isBuiltIn } }

    var body: some View {
        List {
            Section("Canvas") {
                Toggle("Copy clip when tapped", isOn: $copyClipOnTap)
            }

            Section("Tags") {
                ForEach(ClipType.allCases, id: \.self) { type in
                    BuiltInTagSettingsRow(type: type)
                        .listRowSeparator(.hidden)
                }
                ForEach(userTags) { tag in
                    TagSettingsRow(
                        tag: tag,
                        presets: colorPresets,
                        onDelete: { context.delete(tag) }
                    )
                    .listRowSeparator(.hidden)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("New tag", text: $newTagName)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit(createTag)

                        TagColorDot(hex: selectedColor, presets: colorPresets) {
                            selectedColor = $0
                        }

                        Button(action: createTag) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(BlendedIconButtonStyle())
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .listRowSeparator(.hidden)
            }

            Section("Library") {
                NavigationLink(destination: TrashPage()) {
                    Label("Recently Deleted", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .buttonStyle(.plain)
    }

    private func createTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let sortIndex = (tags.map(\.sortIndex).max() ?? 10) + 1
        context.insert(ClipTag(name: trimmed, colorHex: selectedColor, isBuiltIn: false, sortIndex: sortIndex))
        newTagName = ""
    }
}

private struct BuiltInTagSettingsRow: View {
    let type: ClipType

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ClipTag.builtInColor(for: type))
                .frame(width: 22, height: 22)
            AppTagPill(
                title: ClipTag.builtInName(for: type),
                color: ClipTag.builtInColor(for: type),
                icon: type.icon,
                isSelected: false
            )
            Spacer()
            Text("Clip type")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct TagSettingsRow: View {
    @Bindable var tag: ClipTag

    let presets: [String]
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TagColorDot(hex: tag.colorHex, presets: presets) {
                    tag.colorHex = $0
                }

                TextField("Tag name", text: $tag.name)
                    .font(.subheadline.weight(.medium))
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit(normalizeName)

                Menu {
                    Button("Delete Tag", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: AppSymbol.options)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }

    private func normalizeName() {
        let trimmed = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.name = trimmed.isEmpty ? "Untitled" : trimmed
    }
}
