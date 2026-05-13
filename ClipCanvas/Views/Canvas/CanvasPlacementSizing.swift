import CoreGraphics
import Foundation

enum CanvasPlacementSizing {
    static let defaultSize = CGSize(width: 220, height: 150)
    static let minimumSize = CGSize(width: 160, height: 96)
    static let maximumSize = CGSize(width: 440, height: 540)
    static let estimatedCharacterWidth: CGFloat = 8.5
    static let estimatedLineHeight: CGFloat = 20
    static let contentChrome = CGSize(width: 28, height: 28)

    static func toggledSize(for placement: CanvasPlacement, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if isExpanded(placement) { return defaultSize }
        return expandedSize(for: placement.clip, availableScreenWidth: availableScreenWidth)
    }

    static func expandedSize(for clip: Clip?, availableScreenWidth: CGFloat? = nil) -> CGSize {
        guard let clip else { return defaultSize }
        if clip.type == .image {
            let width = min(max((availableScreenWidth ?? 360) - 48, 300), 520)
            return CGSize(width: width, height: min(width * 0.78, 420))
        }

        let count = max(clip.content.count, 1)
        let lines = clip.content.components(separatedBy: .newlines).count
        let estimatedWrappedLines = max(lines, Int((Double(count) / 32.0).rounded(.up)))
        let height = min(max(CGFloat(estimatedWrappedLines) * estimatedLineHeight + 34, defaultSize.height), 420)
        let width: CGFloat = count > 220 ? 300 : 260
        return snappedSize(CGSize(width: width, height: height), for: clip)
    }

    static func snappedSize(_ proposed: CGSize, for clip: Clip?) -> CGSize {
        let widthStep = clip?.type == .image ? 16 : estimatedCharacterWidth
        let heightStep = clip?.type == .image ? 16 : estimatedLineHeight
        let width = snap(proposed.width, chrome: contentChrome.width, step: widthStep)
            .clamped(to: minimumSize.width...maximumSize.width)
        let height = snap(proposed.height, chrome: contentChrome.height, step: heightStep)
            .clamped(to: minimumSize.height...maximumSize.height)
        return CGSize(width: width, height: height)
    }

    static func fluidSize(_ proposed: CGSize) -> CGSize {
        CGSize(
            width: proposed.width.clamped(to: minimumSize.width...maximumSize.width),
            height: proposed.height.clamped(to: minimumSize.height...maximumSize.height)
        )
    }

    private static func snap(_ value: CGFloat, chrome: CGFloat, step: CGFloat) -> CGFloat {
        let contentValue = max(value - chrome, 0)
        return (contentValue / step).rounded() * step + chrome
    }

    private static func isExpanded(_ placement: CanvasPlacement) -> Bool {
        abs(placement.width - defaultSize.width) > 1 || abs(placement.height - defaultSize.height) > 1
    }
}
