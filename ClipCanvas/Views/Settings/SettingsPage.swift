import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsPage: View {
    @AppStorage("settings.trashRetentionDays") private var trashRetentionDays = TrashRetentionService.defaultRetentionDays
    @AppStorage(OpenAIConfiguration.apiKeyUserDefaultsKey) private var openAIAPIKey = ""
    @AppStorage("settings.clipboardMonitoringEnabled") private var clipboardMonitoringEnabled = true
    @AppStorage(ClipboardService.accessEnabledKey) private var clipboardAccessEnabled = false
    @AppStorage("settings.iCloudClipboardSyncEnabled") private var iCloudClipboardSyncEnabled = false
    @AppStorage("settings.allowWorkspaceSharing") private var workspaceSharingEnabled = true
    @AppStorage("settings.includeImagesInShares") private var includeImagesInShares = true

    var body: some View {
        List {
            Section("iCloud") {
                NavigationLink(destination: ICloudProfilePage()) {
                    Label("Profile and Sync", systemImage: "person.crop.circle")
                }
            }

            Section {
                Toggle("Enable Clipboard Features", isOn: $clipboardAccessEnabled)
                Toggle("Monitor Clipboard", isOn: $clipboardMonitoringEnabled)
                    .disabled(!clipboardAccessEnabled)
                #if canImport(UIKit)
                Button {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                } label: {
                    Label("Open System Settings", systemImage: AppSymbol.settings)
                }
                #endif
            } header: {
                Text("Clipboard")
            } footer: {
                Text(clipboardHint)
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
        .onChange(of: clipboardAccessEnabled) { _, enabled in
            if !enabled {
                clipboardMonitoringEnabled = false
                iCloudClipboardSyncEnabled = false
            }
        }
    }

    private var clipboardHint: String {
        #if canImport(UIKit)
        clipboardAccessEnabled
            ? "Controls all clipboard reads and writes. iOS may still ask for paste permission."
            : "Clipboard tools, monitoring, copy, paste, history capture, and clipboard sync are disabled."
        #else
        clipboardAccessEnabled
            ? "Controls all clipboard reads and writes."
            : "Clipboard tools, monitoring, copy, paste, history capture, and clipboard sync are disabled."
        #endif
    }
}
