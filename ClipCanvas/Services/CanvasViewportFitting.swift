import CoreGraphics

nonisolated enum CanvasViewportFitting {
    static func initialOrigin(viewportSize: CGSize, scale: CGFloat) -> CGPoint {
        CanvasViewportBounds.origin(forCenter: .zero, viewportSize: viewportSize, scale: scale)
    }

    static func frame(
        expanding currentFrame: CGRect,
        to targetSize: CGSize,
        bounds: CanvasRadiusBounds
    ) -> CGRect {
        let centeredTopLeft = CGPoint(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.midY - targetSize.height / 2
        )
        let clampedTopLeft = bounds.clampedTopLeft(centeredTopLeft, size: targetSize)
        return CGRect(origin: clampedTopLeft, size: targetSize)
    }

    static func origin(
        revealing frame: CGRect,
        currentOrigin: CGPoint,
        viewportSize: CGSize,
        scale: CGFloat,
        bounds: CanvasRadiusBounds,
        margin: CGFloat = 28
    ) -> CGPoint {
        let safeScale = max(scale, 0.001)
        let visibleSize = CGSize(
            width: viewportSize.width / safeScale,
            height: viewportSize.height / safeScale
        )
        let scaledMargin = margin / safeScale
        var origin = currentOrigin

        if frame.minX < origin.x + scaledMargin {
            origin.x = frame.minX - scaledMargin
        } else if frame.maxX > origin.x + visibleSize.width - scaledMargin {
            origin.x = frame.maxX - visibleSize.width + scaledMargin
        }

        if frame.minY < origin.y + scaledMargin {
            origin.y = frame.minY - scaledMargin
        } else if frame.maxY > origin.y + visibleSize.height - scaledMargin {
            origin.y = frame.maxY - visibleSize.height + scaledMargin
        }

        return CanvasViewportBounds.boundedOrigin(
            origin,
            viewportSize: viewportSize,
            scale: scale,
            bounds: bounds,
            rubberBand: false
        )
    }
}
