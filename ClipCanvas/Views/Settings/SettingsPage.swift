import SwiftUI

struct SettingsPage: View {
    @AppStorage("settings.copyClipOnTap") private var copyClipOnTap = true

    var body: some View {
        List {
            Section("Canvas") {
                Toggle("Copy clip when tapped", isOn: $copyClipOnTap)
            }

            Section("Tags") {
                ClipTagEditor(clips: [], showsClipTypes: true)
                    .padding(.vertical, 4)
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
}
