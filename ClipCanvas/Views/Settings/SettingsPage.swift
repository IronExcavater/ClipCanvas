import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsPage: View {
    @AppStorage("settings.trashRetentionDays") private var trashRetentionDays = TrashRetentionService.defaultRetentionDays
    @AppStorage(OpenAIConfiguration.apiKeyUserDefaultsKey) private var openAIAPIKey = ""
    @AppStorage("settings.clipboardMonitoringEnabled") private var clipboardMonitoringEnabled = true

    var body: some View {
        List {
            Section("Clipboard") {
                Toggle("Monitor Clipboard", isOn: $clipboardMonitoringEnabled)
                Text("When on, ClipCanvas checks your clipboard when the app opens or returns to the foreground and saves new copies to your history.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #if canImport(UIKit)
                Button {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                } label: {
                    Label("Open System Settings", systemImage: "gear")
                }
                #endif
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
