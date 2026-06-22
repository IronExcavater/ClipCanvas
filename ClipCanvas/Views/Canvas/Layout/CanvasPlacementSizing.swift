import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

    static func toggledSize(for object: CanvasObject, availableScreenWidth: CGFloat? = nil) -> CGSize {
        if isExpanded(width: object.width, height: object.height) { return minimumSize }
        return expandedSize(
            for: object.clip,
            fallbackText: object.text,
            availableScreenWidth: availableScreenWidth,
            aspectRatio: imageAspectRatio(for: object.clip)
        )
    }

    static func expandedSize(for clip: Clip?, availableScreenWidth: CGFloat? = nil) -> CGSize {
        expandedSize(
            for: clip,
            fallbackText: nil,
            availableScreenWidth: availableScreenWidth,
            aspectRatio: imageAspectRatio(for: clip)
        )
    }

    static func expandedSize(
        for clip: Clip?,
        fallbackText: String?,
        availableScreenWidth: CGFloat? = nil,
        aspectRatio: CGFloat? = nil
    ) -> CGSize {
        if clip?.type == .image {
            let width = min(max((availableScreenWidth ?? 360) - 48, 300), maximumSize.width)
            let ratio = aspectRatio ?? 1.28
            return snappedSize(
                CGSize(width: width, height: width / max(ratio, 0.001)),
                for: clip,
                aspectRatio: ratio
            )
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

    static func previewSize(for session: CanvasResizeSession, scale: CGFloat, clip: Clip? = nil) -> CGSize {
        snappedSize(session.proposedSize(scale: scale), for: clip, aspectRatio: imageAspectRatio(for: clip), snapsToGrid: false)
    }

    static func committedSize(for session: CanvasResizeSession, scale: CGFloat, clip: Clip?) -> CGSize {
        snappedSize(session.proposedSize(scale: scale), for: clip, aspectRatio: imageAspectRatio(for: clip))
    }

    static func snappedSize(
        _ proposed: CGSize,
        for clip: Clip?,
        aspectRatio: CGFloat? = nil,
        snapsToGrid: Bool = true
    ) -> CGSize {
        if clip?.type == .image {
            return imageSize(for: proposed, aspectRatio: aspectRatio, snapsToGrid: snapsToGrid)
        }
        guard snapsToGrid else { return clampedSize(proposed) }
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

    static func fontSizeForContent(_ text: String, width: CGFloat) -> CGFloat {
        15
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

    private static func imageSize(for proposed: CGSize, aspectRatio: CGFloat?, snapsToGrid: Bool) -> CGSize {
        let ratio = aspectRatio ?? max(proposed.width / max(proposed.height, 1), 0.001)
        var width = proposed.width
        var height = width / max(ratio, 0.001)

        if height > maximumSize.height {
            height = maximumSize.height
            width = height * ratio
        }
        if width > maximumSize.width {
            width = maximumSize.width
            height = width / max(ratio, 0.001)
        }
        if width < minimumSize.width {
            width = minimumSize.width
            height = width / max(ratio, 0.001)
        }
        if height < minimumSize.height {
            height = minimumSize.height
            width = height * ratio
        }

        let clamped = clampedSize(CGSize(width: width, height: height))
        guard snapsToGrid else { return clamped }
        let snappedWidth = snapped(clamped.width, step: 16, chrome: 0)
            .clamped(to: minimumSize.width...maximumSize.width)
        let snappedHeight = (snappedWidth / max(ratio, 0.001))
            .clamped(to: minimumSize.height...maximumSize.height)
        return CGSize(width: snappedWidth, height: snappedHeight)
    }

    private static func imageAspectRatio(for clip: Clip?) -> CGFloat? {
        guard clip?.type == .image,
              let data = clip?.imageData,
              let image = PlatformImage(data: data),
              image.size.height > 0 else {
            return nil
        }
        return image.size.width / image.size.height
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
}
