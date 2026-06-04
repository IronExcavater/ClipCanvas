import SwiftUI

struct CanvasDrawToolSettingsPanel: View {
    let tool: CanvasDrawTool
    let color: PlatformColor?
    let width: CGFloat
    let onChangeColor: (PlatformColor) -> Void
    let onChangeWidth: (CGFloat) -> Void
    let onDismiss: () -> Void

    private var widthRange: ClosedRange<Double> {
        switch tool {
        case .pen: 1...18
        case .highlighter: 8...44
        case .eraser: 18...64
        case .lasso: 0...0
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if color != nil {
                HStack(spacing: 10) {
                    ForEach(colorPresets, id: \.self) { preset in
                        Button {
                            onChangeColor(preset.uiColor)
                        } label: {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if isSelected(preset.uiColor) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                Slider(
                    value: Binding(
                        get: { Double(width) },
                        set: { onChangeWidth(CGFloat($0)) }
                    ),
                    in: widthRange
                )
                .tint(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCapsule()
        .padding(.horizontal, 20)
        .frame(maxWidth: 380)
        .allowsHitTesting(true)
    }

    private var colorPresets: [DrawColorPreset] {
        [
            DrawColorPreset(.label),
            DrawColorPreset(.systemRed),
            DrawColorPreset(.systemOrange),
            DrawColorPreset(.systemYellow),
            DrawColorPreset(.systemGreen),
            DrawColorPreset(.systemBlue),
            DrawColorPreset(.systemPurple),
        ]
    }

    private func isSelected(_ preset: PlatformColor) -> Bool {
        guard let color else { return false }
        #if canImport(UIKit)
        return color.resolvedColor(with: .current).cgColor.components == preset.resolvedColor(with: .current).cgColor.components
        #elseif canImport(AppKit)
        return color.usingColorSpace(.deviceRGB)?.cgColor.components == preset.usingColorSpace(.deviceRGB)?.cgColor.components
        #endif
    }

}

private struct DrawColorPreset: Hashable {
    let uiColor: PlatformColor

    init(_ uiColor: PlatformColor) {
        self.uiColor = uiColor
    }

    var color: Color {
        Color(platformColor: uiColor)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uiColor.description)
    }

    static func == (lhs: DrawColorPreset, rhs: DrawColorPreset) -> Bool {
        lhs.uiColor.description == rhs.uiColor.description
    }
}
