import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ICloudProfilePage: View {
    @AppStorage("settings.iCloudWorkspaceSyncEnabled") private var workspaceSyncEnabled = true
    @AppStorage("settings.iCloudClipboardSyncEnabled") private var clipboardSyncEnabled = false
    @AppStorage(ClipboardService.accessEnabledKey) private var clipboardAccessEnabled = false
    @AppStorage("settings.allowWorkspaceSharing") private var workspaceSharingEnabled = true
    @AppStorage("settings.includeImagesInShares") private var includeImagesInShares = true

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
                        Label("Open iCloud Settings", systemImage: AppSymbol.settings)
                    }
                    #endif
                }
            }

            Section {
                Toggle("Sync Workspaces", isOn: $workspaceSyncEnabled)
                    .disabled(status != .available)
                Toggle("Sync Clipboard Between Devices", isOn: $clipboardSyncEnabled)
                    .disabled(status != .available || !clipboardAccessEnabled)
            } header: {
                Text("Sync")
            } footer: {
                Text(syncHint)
            }

            Section {
                Toggle("Workspace Sharing", isOn: $workspaceSharingEnabled)
                Toggle("Include Images", isOn: $includeImagesInShares)
            } header: {
                Text("Sharing")
            } footer: {
                Text("Controls what ClipCanvas includes when sharing workspaces, cards, and images.")
            }
        }
        .navigationTitle("iCloud Profile")
        .appInlineNavigationTitleDisplayMode()
        .task { status = ICloudAccountService.currentStatus() }
        .onChange(of: clipboardAccessEnabled) { _, enabled in
            if !enabled { clipboardSyncEnabled = false }
        }
    }

    private var statusText: String {
        switch status {
        case .checking: return "Checking account"
        case .available: return "Signed in and available"
        case .noAccount: return "Sign in to iCloud to sync"
        case .unavailable: return "iCloud unavailable"
        }
    }

    private var syncHint: String {
        if !clipboardAccessEnabled {
            return "Clipboard sync requires Clipboard Features to be enabled in Settings."
        }
        return "Sync settings apply only when iCloud is available for this Apple ID."
    }
}
