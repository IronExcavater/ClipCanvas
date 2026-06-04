import SwiftUI

struct TagComposer: View {
    @Binding var name: String
    @Binding var selectedColor: String

    let presets: [String]
    var showsShadow = false
    let onCreate: () -> Void

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 9) {
            TagColorPickerButton(hex: selectedColor, icon: "tag", presets: presets) { selectedColor = $0 }

            TextField("New tag", text: $name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit { if canCreate { onCreate() } }
                .onChange(of: name) { _, newValue in
                    if newValue.count > 30 { name = String(newValue.prefix(30)) }
                }

            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(canCreate ? Color.accentColor : Color.primary.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
        }
        .frame(minHeight: 38)
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Capsule())
        .shadow(color: .black.opacity(showsShadow ? 0.12 : 0), radius: showsShadow ? 12 : 0, y: showsShadow ? 5 : 0)
    }
}

struct TagColorPickerButton: View {
    let hex: String
    let icon: String?
    let presets: [String]
    let onSelect: (String) -> Void

    @State private var showingPalette = false

    var body: some View {
        Button { showingPalette.toggle() } label: {
            Circle()
                .fill(Color(hex: hex) ?? .accentColor)
                .frame(width: 32, height: 32)
                .overlay {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPalette, arrowEdge: .bottom) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            onSelect(preset)
                            showingPalette = false
                        } label: {
                            Circle()
                                .fill(Color(hex: preset) ?? .accentColor)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if preset == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Change color")
    }
}

struct TagDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary.opacity(0.62))
                .frame(width: 32, height: 32)
                .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete tag")
    }
}
