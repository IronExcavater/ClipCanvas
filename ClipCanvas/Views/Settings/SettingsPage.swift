import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsPage: View {
    @AppStorage("settings.trashRetentionDays") private var trashRetentionDays = TrashRetentionService.defaultRetentionDays
    @AppStorage(OpenAIConfiguration.apiKeyUserDefaultsKey) private var openAIAPIKey = ""
    @AppStorage("settings.clipboardMonitoringEnabled") private var clipboardMonitoringEnabled = true
    @AppStorage("settings.iCloudWorkspaceSyncEnabled") private var workspaceSyncEnabled = true
    @AppStorage("settings.iCloudClipboardSyncEnabled") private var clipboardSyncEnabled = false
    @AppStorage("settings.allowWorkspaceSharing") private var workspaceSharingEnabled = true
    @AppStorage("settings.includeImagesInShares") private var includeImagesInShares = true

    var body: some View {
        List {
            Section("iCloud") {
                NavigationLink(destination: ICloudProfilePage()) {
                    Label("Profile and Sync", systemImage: "person.crop.circle")
                }
                Toggle("Sync Workspaces", isOn: $workspaceSyncEnabled)
                Toggle("Sync Clipboard Between Devices", isOn: $clipboardSyncEnabled)
            }

            Section("Clipboard") {
                Toggle("Monitor Clipboard", isOn: $clipboardMonitoringEnabled)
                Text("When on, ClipCanvas checks your clipboard when the app opens or returns to the foreground and saves new copies to your history.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #if canImport(UIKit)
                Text("Still being asked to allow pasting? Open Settings → ClipCanvas → Paste from Other Apps and set it to Allow — iOS won't ask again after that.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                } label: {
                    Label("Open System Settings", systemImage: "gear")
                }
                #endif
            }

            Section("Sharing") {
                Toggle("Allow Workspace Sharing", isOn: $workspaceSharingEnabled)
                Toggle("Include Images in Share Sheets", isOn: $includeImagesInShares)
            }

            Section("AI") {
                SecureField("OpenAI API key", text: $openAIAPIKey)
                    .textContentType(.password)
            }

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
