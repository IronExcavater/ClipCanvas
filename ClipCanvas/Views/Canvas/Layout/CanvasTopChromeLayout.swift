import CoreGraphics

nonisolated enum CanvasTopChromeLayout {
    static let barHeight: CGFloat = 60
    static let searchHeight: CGFloat = 58

    static func expectedHeight(searchActive: Bool) -> CGFloat {
        barHeight + (searchActive ? searchHeight : 0)
    }

    static func resolvedHeight(measuredHeight: CGFloat, expectedHeight: CGFloat) -> CGFloat {
        guard measuredHeight.isFinite, measuredHeight > 1 else {
            return expectedHeight
        }
        return max(measuredHeight, searchActiveMinimum(for: expectedHeight))
    }

    private static func searchActiveMinimum(for expectedHeight: CGFloat) -> CGFloat {
        expectedHeight > barHeight ? expectedHeight : barHeight
    }
}
