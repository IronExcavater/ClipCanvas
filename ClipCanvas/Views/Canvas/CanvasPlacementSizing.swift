import CoreGraphics
import Foundation

enum CanvasPlacementSizing {
    static let characterWidth: CGFloat = 8
    static let lineHeight: CGFloat = 20
    static let contentChrome = CGSize(width: 28, height: 30)

    private static let minimumTextColumns: CGFloat = 14
    private static let maximumTextColumns: CGFloat = 84
    private static let minimumTextLines: CGFloat = 3
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
        let proposedWidth: CGFloat
        if let availableScreenWidth {
            proposedWidth = max(minimumSize.width, min(availableScreenWidth - 48, maximumSize.width))
        } else {
            proposedWidth = content.count > 160 ? 356 : 260
        }
        let width = snappedWidth(proposedWidth)
        return textSize(for: content, width: width)
    }

    static func editingSize(for object: CanvasObject, viewportSize: CGSize, scale: CGFloat) -> CGSize {
        let visibleWidth = viewportSize.width / max(scale, 0.001)
        let proposedWidth = min(max(visibleWidth - 56, minimumSize.width), maximumSize.width)
        let width = snappedWidth(proposedWidth)
        let content = object.clip?.content.isEmpty == false ? (object.clip?.content ?? "") : object.text
        let measured = textSize(for: content, width: width)
        let visibleHeight = viewportSize.height / max(scale, 0.001)
        let maxHeight = max(min(visibleHeight - 160, maximumSize.height), minimumSize.height)
        return snappedSize(
            CGSize(width: width, height: min(max(measured.height, object.height), maxHeight)),
            for: object.clip
        )
    }

    static func frameForEditing(_ frame: CGRect, targetSize: CGSize, viewport: CGRect, margin: CGFloat = 42) -> CGRect {
        let minY = viewport.minY + margin
        let maxY = viewport.maxY - margin - targetSize.height
        let y: CGFloat
        if maxY < minY {
            y = minY
        } else {
            y = frame.minY.clamped(to: minY...maxY)
        }
        return CGRect(x: frame.minX, y: y, width: targetSize.width, height: targetSize.height)
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

    static func textLineCount(for text: String, width: CGFloat) -> Int {
        let columns = max(Int(((width - contentChrome.width) / characterWidth).rounded(.down)), 1)
        let lines = text.isEmpty ? [""] : text.components(separatedBy: .newlines)
        return lines.reduce(0) { partial, line in
            partial + max(Int((Double(max(line.count, 1)) / Double(columns)).rounded(.up)), 1)
        }
    }

    static func fontSizeForWidth(_ width: CGFloat) -> CGFloat {
        (width / 10.0).clamped(to: 15...30)
    }

    static func fontSizeForContent(_ text: String, width: CGFloat) -> CGFloat {
        let chars = CGFloat(text.trimmingCharacters(in: .whitespacesAndNewlines).count)
        let widthNorm = (width / minimumSize.width).clamped(to: 0.8...2.5)
        let base: CGFloat = chars <= 0 ? 28 : 15.0 + 13.0 / (1.0 + chars / 20.0)
        return (base * widthNorm).clamped(to: 13...32)
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

    private static func textSize(for text: String, width: CGFloat) -> CGSize {
        let lines = CGFloat(textLineCount(for: text, width: width))
            .clamped(to: minimumTextLines...maximumTextLines)
        return snappedSize(CGSize(width: width, height: contentChrome.height + lines * lineHeight), for: nil)
    }

    private static func snappedWidth(_ width: CGFloat) -> CGFloat {
        clampedSize(CGSize(width: snapped(width, step: characterWidth, chrome: contentChrome.width), height: minimumSize.height)).width
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
