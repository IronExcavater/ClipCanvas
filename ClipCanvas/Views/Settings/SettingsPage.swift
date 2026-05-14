import SwiftUI

struct SettingsPage: View {
    @AppStorage("settings.trashRetentionDays") private var trashRetentionDays = TrashRetentionService.defaultRetentionDays

    var body: some View {
        List {
            Section("Tags") {
                ClipTagEditor(clips: [], showsClipTypes: true, layout: .twoColumns)
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 10, trailing: 0))
            }

            Section("Library") {
                Picker("Auto-delete after", selection: $trashRetentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                NavigationLink(destination: TrashPage()) {
                    Label("Recently Deleted", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        .appInlineNavigationTitleDisplayMode()
        .buttonStyle(.plain)
    }
}
