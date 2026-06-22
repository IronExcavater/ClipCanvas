import CoreGraphics

nonisolated enum CanvasEditOverlayLayout {
    static func availableFrame(
        viewportSize: CGSize,
        topBarContentHeight: CGFloat,
        keyboardHeight: CGFloat,
        safeAreaBottom: CGFloat
    ) -> CGRect {
        let topInset = topBarContentHeight + 12
        let keyboardInset = keyboardHeight > 0 ? max(keyboardHeight - 12, 0) : safeAreaBottom
        let bottomInset = keyboardInset + 54
        let sideInset: CGFloat = 16
        let width = viewportSize.width - sideInset * 2
        let availableHeight = max(80, viewportSize.height - topInset - bottomInset)
        return CGRect(x: sideInset, y: topInset, width: width, height: availableHeight)
    }
}
