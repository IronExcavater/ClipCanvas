import CoreGraphics
import Foundation

enum CanvasPlacementSizing {
    static let characterWidth: CGFloat = 8
    static let lineHeight: CGFloat = 20
    static let contentChrome = CGSize(width: 28, height: 30)

    private static let minimumTextColumns: CGFloat = 24
    private static let maximumTextColumns: CGFloat = 52
    private static let minimumTextLines: CGFloat = 6
    private static let maximumTextLines: CGFloat = 26

    static let defaultSize = CGSize(
        width: contentChrome.width + minimumTextColumns * characterWidth,
        height: contentChrome.height + minimumTextLines * lineHeight
    )
    static let minimumSize = defaultSize
    static let maximumSize = CGSize(
        width: contentChrome.width + maximumTextColumns * characterWidth,
        height: contentChrome.height + maximumTextLines * lineHeight
    )

    static var estimatedCharacterWidth: CGFloat { characterWidth }
    static var estimatedLineHeight: CGFloat { lineHeight }

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
            return snappedSize(CGSize(width: width, height: min(width * 0.78, maximumSize.height)), for: clip)
        }

        let content = clip?.content.isEmpty == false ? (clip?.content ?? "") : (fallbackText ?? "")
        let count = max(content.count, 1)
        let hardLines = content.components(separatedBy: .newlines).count
        let wrappedLines = max(hardLines, Int((Double(count) / 28).rounded(.up)))
        let width: CGFloat
        if let availableScreenWidth {
            width = max(minimumSize.width, min(availableScreenWidth - 48, maximumSize.width))
        } else {
            width = count > 160 ? 300 : 260
        }
        let height = CGFloat(wrappedLines) * lineHeight + contentChrome.height
        return snappedSize(CGSize(width: width, height: height), for: clip)
    }

    static func previewSize(for session: CanvasResizeSession, scale: CGFloat) -> CGSize {
        fluidSize(dragging: session.proposedSize(scale: scale))
    }

    static func committedSize(for session: CanvasResizeSession, scale: CGFloat, clip: Clip?) -> CGSize {
        snappedSize(session.proposedSize(scale: scale), for: clip)
    }

    static func fluidSize(dragging proposed: CGSize) -> CGSize {
        clampedSize(proposed)
    }

    static func softSnapSize(_ proposed: CGSize) -> CGSize {
        snappedSize(proposed, for: nil)
    }

    static func snappedSize(_ proposed: CGSize, for clip: Clip?) -> CGSize {
        if clip?.type == .image {
            return clampedSize(snap(proposed, widthStep: 16, heightStep: 16, chrome: .zero))
        }
        return clampedSize(snap(
            proposed,
            widthStep: characterWidth,
            heightStep: lineHeight,
            chrome: contentChrome
        ))
    }

    static func fontSizeForWidth(_ width: CGFloat) -> CGFloat {
        (width / 18.0).clamped(to: 11...22)
    }

    static func isExpanded(width: Double, height: Double) -> Bool {
        abs(width - minimumSize.width) > 1 || abs(height - minimumSize.height) > 1
    }

    private static func clampedSize(_ proposed: CGSize) -> CGSize {
        CGSize(
            width: proposed.width.clamped(to: minimumSize.width...maximumSize.width),
            height: proposed.height.clamped(to: minimumSize.height...maximumSize.height)
        )
    }

    private static func snap(
        _ proposed: CGSize,
        widthStep: CGFloat,
        heightStep: CGFloat,
        chrome: CGSize
    ) -> CGSize {
        CGSize(
            width: snapped(proposed.width, step: widthStep, chrome: chrome.width),
            height: snapped(proposed.height, step: heightStep, chrome: chrome.height)
        )
    }

    private static func snapped(_ value: CGFloat, step: CGFloat, chrome: CGFloat) -> CGFloat {
        let content = max(value - chrome, step)
        return chrome + (content / step).rounded() * step
    }

    private static func isExpanded(_ placement: CanvasPlacement) -> Bool {
        isExpanded(width: placement.width, height: placement.height)
    }
}
