import CoreGraphics
import Foundation

enum CanvasPlacementSizing {
    static let defaultSize = CGSize(width: 220, height: 150)
    static let minimumSize = CGSize(width: 220, height: 150)
    static let maximumSize = CGSize(width: 440, height: 540)
    static let contentChrome = CGSize(width: 28, height: 34)
    static let estimatedCharacterWidth: CGFloat = 8
    static let estimatedLineHeight: CGFloat = 20

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
        boundedSize(proposed)
    }

    static func softSnapSize(_ proposed: CGSize) -> CGSize {
        snappedSize(proposed, for: nil)
    }

    static func snappedSize(_ proposed: CGSize, for clip: Clip?) -> CGSize {
        if clip?.type == .image {
            return boundedSize(proposed, step: 16, chrome: .zero)
        }
        return boundedSize(
            proposed,
            widthStep: estimatedCharacterWidth,
            heightStep: estimatedLineHeight,
            chrome: contentChrome
        )
    }

    private static func boundedSize(_ proposed: CGSize, step: CGFloat = 16, chrome: CGSize = .zero) -> CGSize {
        boundedSize(proposed, widthStep: step, heightStep: step, chrome: chrome)
    }

    private static func boundedSize(
        _ proposed: CGSize,
        widthStep: CGFloat,
        heightStep: CGFloat,
        chrome: CGSize
    ) -> CGSize {
        CGSize(
            width: snapped(proposed.width, step: widthStep, chrome: chrome.width)
                .clamped(to: minimumSize.width...maximumSize.width),
            height: snapped(proposed.height, step: heightStep, chrome: chrome.height)
                .clamped(to: minimumSize.height...maximumSize.height)
        )
    }

    static func fontSizeForWidth(_ width: CGFloat) -> CGFloat {
        (width / 18.0).clamped(to: 11...22)
    }

    private static func snapped(_ value: CGFloat, step: CGFloat, chrome: CGFloat) -> CGFloat {
        let content = max(value - chrome, step)
        return chrome + (content / step).rounded() * step
    }

    private static func isExpanded(_ placement: CanvasPlacement) -> Bool {
        isExpanded(width: placement.width, height: placement.height)
    }

    static func isExpanded(width: Double, height: Double) -> Bool {
        abs(width - minimumSize.width) > 1 || abs(height - minimumSize.height) > 1
    }
}
