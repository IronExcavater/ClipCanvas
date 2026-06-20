import SwiftUI

struct CanvasColorPanel: View {
    let objects: [CanvasObject]
    let onDismiss: () -> Void

    private let presets = [
        "#FFF3B0", "#FFD166", "#FF9800", "#4CAF50",
        "#2196F3", "#9C27B0", "#E91E63", "#FFFFFF"
    ]

    var body: some View {
        CanvasOverlayPanel(
            title: objects.count > 1 ? "\(objects.count) cards selected" : "Note Color",
            systemImage: "paintpalette",
            onDismiss: onDismiss
        ) {
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
