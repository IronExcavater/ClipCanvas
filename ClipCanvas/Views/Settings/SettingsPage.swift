import SwiftUI

struct SettingsPage: View {
    @AppStorage("settings.copyClipOnTap") private var copyClipOnTap = true

    var body: some View {
        List {
            Section("Canvas") {
                Toggle("Copy clip when tapped", isOn: $copyClipOnTap)
            }

            Section("Clip Types") {
                ForEach(ClipType.allCases, id: \.self) { type in
                    BuiltInTagSettingsRow(type: type)
                        .listRowSeparator(.hidden)
                }
            }

            Section("User Tags") {
                ClipTagEditor(clips: [])
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

private struct BuiltInTagSettingsRow: View {
    let type: ClipType

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ClipTag.builtInColor(for: type))
                .frame(width: 22, height: 22)
            AppTagPill(
                title: ClipTag.builtInName(for: type),
                color: ClipTag.builtInColor(for: type),
                icon: type.icon,
                isSelected: false
            )
            Spacer()
            Text("Clip type")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.66))
        }
        .padding(.vertical, 2)
    }
}
