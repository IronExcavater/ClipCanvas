import SwiftData
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

    @Query(filter: #Predicate<Workspace> { $0.deletedAt == nil }, sort: \Workspace.sortIndex)
    private var workspaces: [Workspace]
    @Query(filter: #Predicate<Clip> { $0.deletedAt == nil }, sort: \Clip.updatedAt, order: .reverse)
    private var clips: [Clip]

    @State private var status: ICloudProfileStatus = .checking

    var body: some View {
        List {
            Section { profileSummary }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

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
                Toggle("Include Images", isOn: $includeImagesInShares)
            } header: {
                Text("Sharing")
            } footer: {
                Text("Controls whether ClipCanvas includes image files when sharing cards and workspaces.")
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

    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: status == .available ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Circle()
                        .fill(statusBadgeColor)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Color.platformSystemBackground, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud")
                        .font(.title3.weight(.semibold))
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(syncSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            #if canImport(UIKit)
            Button {
                openAppleIDSettings()
            } label: {
                Label(status == .available ? "Manage Apple ID and iCloud" : "Open iCloud Settings", systemImage: AppSymbol.settings)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
        .padding(.vertical, 8)
    }

    private var syncSummary: String {
        if workspaceSyncEnabled && clipboardSyncEnabled {
            return "Workspaces and clipboard sync are on"
        }
        if workspaceSyncEnabled {
            return "Workspace sync is on"
        }
        if clipboardSyncEnabled {
            return "Clipboard sync is on"
        }
        return "Sync is off"
    }

    private var statusBadgeColor: Color {
        switch status {
        case .available: return .green
        case .checking: return .orange
        case .noAccount, .unavailable: return .secondary
        }
    }

    #if canImport(UIKit)
    private func openAppleIDSettings() {
        let urls = [
            URL(string: "App-prefs:APPLE_ACCOUNT"),
            URL(string: UIApplication.openSettingsURLString)
        ].compactMap { $0 }
        guard let url = urls.first else { return }
        UIApplication.shared.open(url)
    }
    #endif
}
