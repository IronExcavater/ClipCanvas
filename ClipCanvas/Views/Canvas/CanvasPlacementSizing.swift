import CoreGraphics
import Foundation

enum CanvasPlacementSizing {
    static let defaultSize = CGSize(width: 220, height: 150)
    static let minimumSize = CGSize(width: 220, height: 150)
    static let maximumSize = CGSize(width: 440, height: 540)
    static let snapGrid: CGFloat = 16

    static func toggledSize(for placement: CanvasPlacement, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if isExpanded(placement) { return minimumSize }
        return expandedSize(for: placement.clip, availableScreenWidth: availableScreenWidth)
    }

    static func toggledSize(for object: CanvasObject, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if isExpanded(width: object.width, height: object.height) { return minimumSize }
        return expandedSize(for: object.clip, fallbackText: object.text, availableScreenWidth: availableScreenWidth)
    }

    static func expandedSize(for clip: Clip?, availableScreenWidth: CGFloat? = nil) -> CGSize {
        expandedSize(for: clip, fallbackText: nil, availableScreenWidth: availableScreenWidth)
    }

    static func expandedSize(for clip: Clip?, fallbackText: String?, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if clip?.type == .image {
            let width = min(max((availableScreenWidth ?? 360) - 48, 300), maximumSize.width)
            return softSnapSize(CGSize(width: width, height: min(width * 0.78, maximumSize.height)))
        }

        let content = clip?.content.isEmpty == false ? (clip?.content ?? "") : (fallbackText ?? "")
        let lineHeight: CGFloat = 20
        let charsPerLine: Double = 28
        let count = max(content.count, 1)
        let hardLines = content.components(separatedBy: .newlines).count
        let wrappedLines = max(hardLines, Int((Double(count) / charsPerLine).rounded(.up)))
        let estimatedHeight = CGFloat(wrappedLines) * lineHeight + 40

        let width: CGFloat = count > 160 ? 300 : 260
        let height = estimatedHeight.clamped(to: minimumSize.height...maximumSize.height)
        return softSnapSize(CGSize(width: width, height: height))
    }

    static func fluidSize(dragging proposed: CGSize) -> CGSize {
        softSnapSize(proposed)
    }

    static func softSnapSize(_ proposed: CGSize) -> CGSize {
        CGSize(
            width: softSnap(proposed.width).clamped(to: minimumSize.width...maximumSize.width),
            height: softSnap(proposed.height).clamped(to: minimumSize.height...maximumSize.height)
        )
    }

    static func fontSizeForWidth(_ width: CGFloat) -> CGFloat {
        (width / 18.0).clamped(to: 11...22)
    }

    private static func softSnap(_ value: CGFloat) -> CGFloat {
        (value / snapGrid).rounded() * snapGrid
    }

    private static func isExpanded(_ placement: CanvasPlacement) -> Bool {
        isExpanded(width: placement.width, height: placement.height)
    }

    static func isExpanded(width: Double, height: Double) -> Bool {
        abs(width - minimumSize.width) > 1 || abs(height - minimumSize.height) > 1
    }
}
