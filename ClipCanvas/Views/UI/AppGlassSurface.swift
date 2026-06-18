import SwiftUI

enum AppGlassShape {
    case circle
    case capsule
    case rect(cornerRadius: CGFloat)
}

enum AppGlassFallback {
    case material(Material)
    case color(Color)
}

struct AppGlassSurface: View {
    let shape: AppGlassShape
    var tint: Color?
    var fallback: AppGlassFallback = .material(.regularMaterial)
    var interactive = false
    var stroke: Color?
    var strokeWidth: CGFloat = 1

    var body: some View {
        ZStack {
            surface
            if let stroke {
                strokeSurface(color: stroke)
            }
        }
    }

    @ViewBuilder
    private var surface: some View {
        if #available(iOS 26, *) {
            switch shape {
            case .circle:
                Circle()
                    .fill(Color.clear)
                    .appGlassEffect(tint: tint, interactive: interactive, in: .circle)
            case .capsule:
                Capsule()
                    .fill(Color.clear)
                    .appGlassEffect(tint: tint, interactive: interactive, in: .capsule)
            case .rect(let cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .appGlassEffect(tint: tint, interactive: interactive, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            fallbackSurface
        }
    }

    @ViewBuilder
    private var fallbackSurface: some View {
        switch (shape, fallback) {
        case (.circle, .material(let material)):
            Circle().fill(material)
        case (.circle, .color(let color)):
            Circle().fill(color)
        case (.capsule, .material(let material)):
            Capsule().fill(material)
        case (.capsule, .color(let color)):
            Capsule().fill(color)
        case (.rect(let cornerRadius), .material(let material)):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(material)
        case (.rect(let cornerRadius), .color(let color)):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(color)
        }
    }

    @ViewBuilder
    private func strokeSurface(color: Color) -> some View {
        switch shape {
        case .circle:
            Circle().stroke(color, lineWidth: strokeWidth)
        case .capsule:
            Capsule().stroke(color, lineWidth: strokeWidth)
        case .rect(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(color, lineWidth: strokeWidth)
        }
    }
}

private extension View {
    @ViewBuilder
    func appGlassEffect<S: Shape>(tint: Color?, interactive: Bool, in shape: S) -> some View {
        if let tint {
            if interactive {
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.tint(tint), in: shape)
            }
        } else if interactive {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.glassEffect(.regular, in: shape)
        }
    }
}
