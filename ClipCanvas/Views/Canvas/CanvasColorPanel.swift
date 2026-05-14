import SwiftUI

struct CanvasColorPanel: View {
    let objects: [CanvasObject]
    let onDismiss: () -> Void

    private let presets = [
        "#FFF3B0", "#FFD166", "#FF9800", "#4CAF50",
        "#2196F3", "#9C27B0", "#E91E63", "#FFFFFF"
    ]

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 42), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(presets, id: \.self) { hex in
                        ColorSwatch(hex: hex, isSelected: selectedHex == hex) {
                            apply(hex)
                        }
                    }
                }
            }
            .padding(12)
            .background {
                if #available(iOS 26, *) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 26))
                } else {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
            .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
            .padding(.horizontal, 18)
            .padding(.bottom, 92)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var selectedHex: String? {
        guard let first = objects.first?.style.fillHex,
              objects.allSatisfy({ $0.style.fillHex == first }) else {
            return nil
        }
        return first
    }

    private func apply(_ hex: String) {
        for object in objects {
            var style = object.style
            style.fillHex = hex
            object.style = style
            object.markUpdated()
        }
        onDismiss()
    }
}

private struct ColorSwatch: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex) ?? .accentColor)
                .frame(width: 38, height: 38)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.primary.opacity(0.82) : Color.primary.opacity(0.12),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set note color \(hex)")
    }
}
