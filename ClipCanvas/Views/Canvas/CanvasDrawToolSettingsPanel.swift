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
        ZStack(alignment: .bottom) {
            Color.clear.allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 10) {
                if color != nil {
                    HStack(spacing: 8) {
                        ForEach(colorPresets, id: \.self) { preset in
                            Button {
                                onChangeColor(preset.uiColor)
                            } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if isSelected(preset.uiColor) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Slider(
                        value: Binding(
                            get: { Double(width) },
                            set: { onChangeWidth(CGFloat($0)) }
                        ),
                        in: widthRange
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background { panelBackground }
            .padding(.horizontal, 18)
            .padding(.bottom, 118)
            .frame(maxWidth: 360)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
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

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.regularMaterial)
        }
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
