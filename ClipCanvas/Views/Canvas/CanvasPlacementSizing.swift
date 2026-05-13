import CoreGraphics
import Foundation

enum CanvasPlacementSizing {
    static let defaultSize = CGSize(width: 220, height: 150)
    static let minimumSize = CGSize(width: 160, height: 96)
    static let maximumSize = CGSize(width: 440, height: 540)
    static let estimatedCharacterWidth: CGFloat = 8
    static let estimatedLineHeight: CGFloat = 20
    static let contentChrome = CGSize(width: 28, height: 30)

    static func toggledSize(for placement: CanvasPlacement, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if isExpanded(placement) { return defaultSize }
        return expandedSize(for: placement.clip, availableScreenWidth: availableScreenWidth)
    }

    static func toggledSize(for object: CanvasObject, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if isExpanded(width: object.width, height: object.height) { return defaultSize }
        return expandedSize(for: object.clip, fallbackText: object.text, availableScreenWidth: availableScreenWidth)
    }

    static func expandedSize(for clip: Clip?, availableScreenWidth: CGFloat? = nil) -> CGSize {
        expandedSize(for: clip, fallbackText: nil, availableScreenWidth: availableScreenWidth)
    }

    static func expandedSize(for clip: Clip?, fallbackText: String?, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if clip?.type == .image {
            let width = min(max((availableScreenWidth ?? 360) - 48, 300), 520)
            return CGSize(width: width, height: min(width * 0.78, 420))
        }

        let content = clip?.content.isEmpty == false ? (clip?.content ?? "") : (fallbackText ?? "")
        let count = max(content.count, 1)
        let lines = content.components(separatedBy: .newlines).count
        let estimatedWrappedLines = max(lines, Int((Double(count) / 32.0).rounded(.up)))
        let height = min(max(CGFloat(estimatedWrappedLines) * estimatedLineHeight + 34, defaultSize.height), 420)
        let width: CGFloat = count > 220 ? 300 : 260
        return snappedSize(CGSize(width: width, height: height), for: clip)
    }

    static func snappedSize(_ proposed: CGSize, for clip: Clip?) -> CGSize {
        if clip?.type == .image {
            return CGSize(
                width: snap(proposed.width, chrome: 0, step: 16).clamped(to: minimumSize.width...maximumSize.width),
                height: snap(proposed.height, chrome: 0, step: 16).clamped(to: minimumSize.height...maximumSize.height)
            )
        }

        let width = snappedTextWidth(proposed.width)
        let height = snappedTextHeight(proposed.height)
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

    private static func snappedTextWidth(_ value: CGFloat) -> CGFloat {
        let contentWidth = value - contentChrome.width
        let columns = (contentWidth / estimatedCharacterWidth).rounded()
            .clamped(to: CGFloat(16)...CGFloat(52))
        return columns * estimatedCharacterWidth + contentChrome.width
    }

    private static func snappedTextHeight(_ value: CGFloat) -> CGFloat {
        let contentHeight = value - contentChrome.height
        let rows = (contentHeight / estimatedLineHeight).rounded()
            .clamped(to: CGFloat(4)...CGFloat(26))
        return rows * estimatedLineHeight + contentChrome.height
    }

    private static func isExpanded(_ placement: CanvasPlacement) -> Bool {
        isExpanded(width: placement.width, height: placement.height)
    }

    private static func isExpanded(width: Double, height: Double) -> Bool {
        abs(width - defaultSize.width) > 1 || abs(height - defaultSize.height) > 1
    }
}
