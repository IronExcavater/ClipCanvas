import CoreGraphics

nonisolated enum CanvasScaleSteps {
    static let values: [CGFloat] = [0.25, 0.33, 0.5, 0.67, 0.8, 1, 1.25, 1.5, 2, 3, 4]

    static var minimum: CGFloat { values.first ?? 0.25 }
    static var maximum: CGFloat { values.last ?? 4 }

    static func clamp(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimum), maximum)
    }

    static func nearest(_ scale: CGFloat) -> CGFloat {
        let clamped = clamp(scale)
        return values.min { lhs, rhs in
            abs(lhs - clamped) < abs(rhs - clamped)
        } ?? clamped
    }

    static func fitting(_ scale: CGFloat) -> CGFloat {
        let clamped = clamp(scale)
        return values.reversed().first { $0 <= clamped } ?? minimum
    }

    static func nextZoomIn(from scale: CGFloat) -> CGFloat {
        let clamped = clamp(scale)
        return values.first { $0 > clamped + 0.001 } ?? maximum
    }

    static func nextZoomOut(from scale: CGFloat) -> CGFloat {
        let clamped = clamp(scale)
        return values.reversed().first { $0 < clamped - 0.001 } ?? minimum
    }
}
