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

    private var title: String {
        switch tool {
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 14) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 82, alignment: .leading)

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

                Slider(
                    value: Binding(
                        get: { Double(width) },
                        set: { onChangeWidth(CGFloat($0)) }
                    ),
                    in: widthRange
                )
                .frame(minWidth: 110)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background { panelBackground }
            .padding(.horizontal, 18)
            .padding(.bottom, 118)
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
