import SwiftUI
import SwiftData

struct SettingsPage: View {
    @AppStorage("settings.copyClipOnTap") private var copyClipOnTap = true
    @AppStorage("settings.fitCanvasAfterDrop") private var fitCanvasAfterDrop = false
    @AppStorage("settings.showResizeHandles") private var showResizeHandles = true
    @AppStorage("settings.deduplicateHistory") private var deduplicateHistory = true
    @AppStorage("settings.maskSensitiveContent") private var maskSensitiveContent = true
    @AppStorage("settings.useTagColors") private var useTagColors = true
    @AppStorage("settings.enableLiquidGlass") private var enableLiquidGlass = true
    @AppStorage("settings.includeAIContext") private var includeAIContext = true

    @Query(filter: #Predicate<Clip> { $0.deletedAt == nil }) private var clips: [Clip]
    @Query(filter: #Predicate<Clip> { $0.deletedAt != nil }) private var deletedClips: [Clip]
    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }) private var workspaces: [Workspace]
    @Query(sort: \ClipTag.sortIndex) private var tags: [ClipTag]

    var body: some View {
        List {
            Section("Canvas") {
                Toggle("Copy clip when tapped", isOn: $copyClipOnTap)
                Toggle("Fit canvas after drop", isOn: $fitCanvasAfterDrop)
                Toggle("Show resize handles", isOn: $showResizeHandles)
            }

            Section("History") {
                Toggle("Deduplicate clipboard history", isOn: $deduplicateHistory)
                Toggle("Mask sensitive previews", isOn: $maskSensitiveContent)
                LabeledContent("Saved clips", value: "\(clips.count)")
            }

            Section("Appearance") {
                Toggle("Use tag colors for notes", isOn: $useTagColors)
                Toggle("Liquid glass controls", isOn: $enableLiquidGlass)
                LabeledContent("Workspaces", value: "\(workspaces.count)")
            }

            Section("Tags") {
                ForEach(ClipType.allCases, id: \.self) { type in
                    tagPreview(
                        name: ClipTag.builtInName(for: type),
                        color: ClipTag.builtInColor(for: type),
                        detail: "Built in"
                    )
                }
                ForEach(tags.filter { !$0.isBuiltIn }) { tag in
                    tagPreview(name: tag.name, color: tag.color, detail: "Custom")
                }
                Button {
                    // Future: open tag editor.
                } label: {
                    Label("Manage Tags", systemImage: "tag")
                }
                .disabled(true)
            }

            Section("AI") {
                Toggle("Include selected clips as context", isOn: $includeAIContext)
                Button {
                    // Future: provider and model configuration.
                } label: {
                    Label("Model and Provider", systemImage: "sparkles")
                }
                .disabled(true)
            }

            Section("Data") {
                NavigationLink(destination: TrashPage()) {
                    Label("Recently Deleted", systemImage: "trash")
                }
                LabeledContent("Deleted clips", value: "\(deletedClips.count)")
                Button {
                    // Future: export a portable archive.
                } label: {
                    Label("Export Library", systemImage: "square.and.arrow.up")
                }
                .disabled(true)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .buttonStyle(.plain)
    }

    private func tagPreview(name: String, color: Color, detail: String) -> some View {
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
}
