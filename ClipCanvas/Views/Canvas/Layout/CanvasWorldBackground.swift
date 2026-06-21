import SwiftUI

struct CanvasDotGrid: View, Animatable {
    var viewportOrigin: CGPoint
    var canvasScale: CGFloat
    var boundsRadius: CGFloat

    private let spacing: CGFloat = 28

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(viewportOrigin.x, viewportOrigin.y),
                AnimatablePair(canvasScale, boundsRadius)
            )
        }
        set {
            viewportOrigin = CGPoint(x: newValue.first.first, y: newValue.first.second)
            canvasScale = newValue.second.first
            boundsRadius = newValue.second.second
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let scale = max(canvasScale, 0.001)
            let densityStep = CGFloat(max(1, Int(ceil(7 / max(spacing * scale, 0.001)))))
            let worldSpacing = spacing * densityStep
            let screenSpacing = worldSpacing * scale
            let phaseX = positiveRemainder(-viewportOrigin.x * scale, screenSpacing)
            let phaseY = positiveRemainder(-viewportOrigin.y * scale, screenSpacing)
            let radius = (1.05 * sqrt(scale)).clamped(to: 0.62...1.75)
            let opacity = (0.24 + min(scale, 1.4) * 0.08).clamped(to: 0.22...0.36)

            var screenX = phaseX - screenSpacing
            while screenX <= size.width + screenSpacing {
                var screenY = phaseY - screenSpacing
                while screenY <= size.height + screenSpacing {
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: screenX - radius,
                            y: screenY - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(.secondary.opacity(Double(opacity)))
                    )
                    screenY += screenSpacing
                }
                screenX += screenSpacing
            }
        }
        .background { CanvasWorldSurface() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func positiveRemainder(_ value: CGFloat, _ divisor: CGFloat) -> CGFloat {
        guard divisor > 0 else { return 0 }
        let result = value.truncatingRemainder(dividingBy: divisor)
        return result >= 0 ? result : result + divisor
    }
}

private struct CanvasWorldSurface: View {
    var body: some View {
        ZStack {
            Color.platformSystemBackground
            Color.platformSecondarySystemBackground.opacity(0.34)
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.035),
                    Color.clear,
                    Color.accentColor.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct EmptyCanvasHint: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Add a card or image")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.platformSystemBackground.opacity(0.92),
                            Color.platformSystemBackground.opacity(0.60),
                            Color.platformSystemBackground.opacity(0.00),
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 148
                    )
                )
                .frame(width: 300, height: 220)
                .blur(radius: 8)
        }
        .allowsHitTesting(false)
    }
}
