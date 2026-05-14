import CoreGraphics

nonisolated struct CanvasRadiusBounds: Equatable {
    let center: CGPoint
    let radius: CGFloat

    init(center: CGPoint = .zero, radius: CGFloat) {
        self.center = center
        self.radius = radius
    }

    func bounded(_ point: CGPoint, rubberBand: Bool) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard distance > radius, distance > 0 else { return point }

        let overflow = distance - radius
        let boundedDistance = rubberBand ? radius + overflow * 0.24 : radius
        return CGPoint(
            x: center.x + dx / distance * boundedDistance,
            y: center.y + dy / distance * boundedDistance
        )
    }

    func clampedTopLeft(_ topLeft: CGPoint, size: CGSize) -> CGPoint {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let objectCenter = CGPoint(x: topLeft.x + halfWidth, y: topLeft.y + halfHeight)
        let usableRadius = max(radius - hypot(halfWidth, halfHeight), 120)
        let dx = objectCenter.x - center.x
        let dy = objectCenter.y - center.y
        let distance = hypot(dx, dy)
        guard distance > usableRadius, distance > 0 else { return topLeft }

        let clampedCenter = CGPoint(
            x: center.x + dx / distance * usableRadius,
            y: center.y + dy / distance * usableRadius
        )
        return CGPoint(x: clampedCenter.x - halfWidth, y: clampedCenter.y - halfHeight)
    }
}

nonisolated enum CanvasViewportBounds {
    static let defaultViewportSize = CGSize(width: 393, height: 852)
    static let minimumRadius: CGFloat = 620
    static let defaultObjectArea: CGFloat = 220 * 150

    static func radius(
        forObjectSizes objectSizes: [CGSize],
        viewportSize: CGSize,
        scale: CGFloat
    ) -> CanvasRadiusBounds {
        let safeScale = max(scale, 0.001)
        let totalArea = objectSizes.reduce(CGFloat(0)) { partial, size in
            partial + size.width * size.height
        }
        let largestDiagonal = objectSizes
            .map { hypot($0.width, $0.height) }
            .max() ?? 260
        let viewportRadius = hypot(viewportSize.width / safeScale, viewportSize.height / safeScale) / 2
        let contentWeight = sqrt(max(totalArea, defaultObjectArea))
        let radius = max(
            minimumRadius,
            viewportRadius * 0.52 + contentWeight * 1.05 + largestDiagonal * 0.45 + CGFloat(objectSizes.count) * 18
        )
        return CanvasRadiusBounds(radius: radius)
    }

    static func viewportCenter(origin: CGPoint, viewportSize: CGSize, scale: CGFloat) -> CGPoint {
        let safeScale = max(scale, 0.001)
        return CGPoint(
            x: origin.x + viewportSize.width / (2 * safeScale),
            y: origin.y + viewportSize.height / (2 * safeScale)
        )
    }

    static func origin(forCenter center: CGPoint, viewportSize: CGSize, scale: CGFloat) -> CGPoint {
        let safeScale = max(scale, 0.001)
        return CGPoint(
            x: center.x - viewportSize.width / (2 * safeScale),
            y: center.y - viewportSize.height / (2 * safeScale)
        )
    }

    static func boundedOrigin(
        _ proposedOrigin: CGPoint,
        viewportSize: CGSize,
        scale: CGFloat,
        bounds: CanvasRadiusBounds,
        rubberBand: Bool
    ) -> CGPoint {
        let proposedCenter = viewportCenter(origin: proposedOrigin, viewportSize: viewportSize, scale: scale)
        let boundedCenter = bounds.bounded(proposedCenter, rubberBand: rubberBand)
        return origin(forCenter: boundedCenter, viewportSize: viewportSize, scale: scale)
    }
}
