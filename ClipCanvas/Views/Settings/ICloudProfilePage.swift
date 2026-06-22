import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ICloudProfilePage: View {
    @AppStorage("settings.iCloudWorkspaceSyncEnabled") private var workspaceSyncEnabled = true
    @AppStorage("settings.iCloudClipboardSyncEnabled") private var clipboardSyncEnabled = false
    @AppStorage("settings.allowWorkspaceSharing") private var workspaceSharingEnabled = true
    @AppStorage("settings.includeImagesInShares") private var includeImagesInShares = true
    @AppStorage("settings.sharePrivateContent") private var sharePrivateContent = false

    @State private var status: ICloudProfileStatus = .checking

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iCloud")
                            .font(.headline)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)

                if status == .noAccount {
                    #if canImport(UIKit)
                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        Label("Open iCloud Settings", systemImage: "gear")
                    }
                    #endif
                }
            }

            Section("Sync") {
                Toggle("Sync Workspaces", isOn: $workspaceSyncEnabled)
                    .disabled(status != .available)
                Toggle("Sync Clipboard Between Devices", isOn: $clipboardSyncEnabled)
                    .disabled(status != .available)
                Text("Clipboard sync uses iCloud key-value storage for recent clipboard text and small images. Workspace sync is enabled for iCloud-backed installs and sharing exports.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Sharing") {
                Toggle("Allow Workspace Sharing", isOn: $workspaceSharingEnabled)
                Toggle("Include Images in Share Sheets", isOn: $includeImagesInShares)
                Toggle("Include Private Content", isOn: $sharePrivateContent)
                Text("Private content stays excluded from share payloads unless you explicitly allow it here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("iCloud Profile")
        .appInlineNavigationTitleDisplayMode()
        .task { status = ICloudAccountService.currentStatus() }
    }

    private var statusText: String {
        switch status {
        case .checking: return "Checking account"
        case .available: return "Signed in and available"
        case .noAccount: return "Sign in to iCloud to sync"
        case .unavailable: return "iCloud unavailable"
        }
    }
}
