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
            let radius = min(max(1.18 * scale, 0.65), 2.2)
            let visibleMinX = viewportOrigin.x - spacing
            let visibleMinY = viewportOrigin.y - spacing
            let visibleMaxX = viewportOrigin.x + size.width / scale + spacing
            let visibleMaxY = viewportOrigin.y + size.height / scale + spacing
            let startColumn = Int(floor(visibleMinX / spacing))
            let endColumn = Int(ceil(visibleMaxX / spacing))
            let startRow = Int(floor(visibleMinY / spacing))
            let endRow = Int(ceil(visibleMaxY / spacing))

            for column in startColumn...endColumn {
                let worldX = CGFloat(column) * spacing
                let screenX = (worldX - viewportOrigin.x) * scale

                for row in startRow...endRow {
                    let worldY = CGFloat(row) * spacing
                    let screenY = (worldY - viewportOrigin.y) * scale
                    let opacity = dotOpacity(at: CGPoint(x: worldX, y: worldY))

                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: screenX - radius,
                            y: screenY - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(.secondary.opacity(opacity))
                    )
                }
            }
        }
        .background { CanvasWorldSurface() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dotOpacity(at point: CGPoint) -> Double {
        let distanceFromOrigin = hypot(point.x, point.y)
        let fadeStart = boundsRadius * 0.56
        let fadeEnd = boundsRadius
        let progress = ((distanceFromOrigin - fadeStart) / max(fadeEnd - fadeStart, 1)).clamped(to: 0...1)
        let eased = progress * progress * (3 - 2 * progress)
        return 0.48 - eased * 0.45
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
            Text("Add a card, text, or image")
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
