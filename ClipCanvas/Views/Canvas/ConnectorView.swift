import SwiftUI

struct ConnectorView: View {
    let connector: CanvasConnector
    let viewportOrigin: CGPoint
    let canvasScale: CGFloat
    let isSelected: Bool

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: screenPoint(connector.start.point.cgPoint))
            path.addLine(to: screenPoint(connector.end.point.cgPoint))
            context.stroke(
                path,
                with: .color(isSelected ? .accentColor : .secondary.opacity(0.72)),
                lineWidth: isSelected ? 3 : 2
            )
        }
        .allowsHitTesting(false)
    }

    private func screenPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - viewportOrigin.x) * canvasScale,
            y: (point.y - viewportOrigin.y) * canvasScale
        )
    }
}
