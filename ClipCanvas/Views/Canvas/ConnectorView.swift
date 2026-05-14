import SwiftUI

struct ConnectorView: View {
    let connector: CanvasConnector
    let viewportOrigin: CGPoint
    let canvasScale: CGFloat
    let isSelected: Bool
    var objectLookup: [UUID: CanvasObject] = [:]

    var body: some View {
        Canvas { ctx, _ in
            let start = resolve(connector.start)
            let end = resolve(connector.end)

            let lineColor: GraphicsContext.Shading = .color(isSelected ? .accentColor : Color.secondary.opacity(0.72))
            let lineWidth: CGFloat = isSelected ? 3 : 2

            var line = Path()
            line.move(to: start)
            line.addLine(to: end)
            ctx.stroke(line, with: lineColor, lineWidth: lineWidth)

            guard start != end else { return }
            let angle = atan2(end.y - start.y, end.x - start.x)
            let len: CGFloat = 10
            let spread: CGFloat = .pi / 5
            var arrow = Path()
            arrow.move(to: end)
            arrow.addLine(to: CGPoint(x: end.x - len * cos(angle - spread), y: end.y - len * sin(angle - spread)))
            arrow.move(to: end)
            arrow.addLine(to: CGPoint(x: end.x - len * cos(angle + spread), y: end.y - len * sin(angle + spread)))
            ctx.stroke(arrow, with: lineColor, lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }

    private func resolve(_ ep: CanvasConnectorEndpoint) -> CGPoint {
        if let id = ep.objectID, let obj = objectLookup[id] {
            return toScreen(anchorPoint(for: obj, anchor: ep.anchor))
        }
        return toScreen(ep.point.cgPoint)
    }

    private func anchorPoint(for obj: CanvasObject, anchor: CanvasAnchor) -> CGPoint {
        let f = obj.frame
        switch anchor {
        case .top:      return CGPoint(x: f.midX, y: f.minY)
        case .trailing: return CGPoint(x: f.maxX, y: f.midY)
        case .bottom:   return CGPoint(x: f.midX, y: f.maxY)
        case .leading:  return CGPoint(x: f.minX, y: f.midY)
        default:        return CGPoint(x: f.midX, y: f.midY)
        }
    }

    private func toScreen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - viewportOrigin.x) * canvasScale,
                y: (point.y - viewportOrigin.y) * canvasScale)
    }
}
