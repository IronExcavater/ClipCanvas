import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var snippets: [Snippet]
    @Query private var workspaces: [Workspace]
    @Query private var transformRuns: [TransformRun]
    @Query private var chatThreads: [WorkspaceChatThread]

    @AppStorage("normalExpiryDays") private var normalExpiryDays = 30
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Normal clips expire", selection: $normalExpiryDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("Never").tag(-1)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Sensitive content expires after 1 day. Private-looking secrets expire after 1 hour.")
                }

                Section("Local Data") {
                    LabeledContent("Workspaces", value: "\(workspaces.filter { !$0.isArchived }.count)")
                    LabeledContent("Library items", value: "\(snippets.count)")
                    LabeledContent("Transforms", value: "\(transformRuns.count)")
                    LabeledContent("Chat threads", value: "\(chatThreads.count)")
                    Button("Reset Local Data", role: .destructive) {
                        showResetConfirmation = true
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Reset Local Data", isPresented: $showResetConfirmation) {
                Button("Delete Everything", role: .destructive, action: resetLocalData)
            } message: {
                Text("Deletes workspaces, cards, snippets, transforms, and workspace chats.")
            }
        }
    }

    private func resetLocalData() {
        for item in snippets { modelContext.delete(item) }
        for item in transformRuns { modelContext.delete(item) }
        for item in chatThreads { modelContext.delete(item) }
        for item in workspaces { modelContext.delete(item) }
        let workspace = Workspace(name: "Canvas", sortIndex: 0, isActive: true)
        modelContext.insert(workspace)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }
}
