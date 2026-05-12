import CoreGraphics
import Foundation

enum CanvasPlacementSizing {
    static let defaultSize = CGSize(width: 220, height: 150)

    static func toggledSize(for placement: CanvasPlacement) -> CGSize {
        if isExpanded(placement) { return defaultSize }
        return expandedSize(for: placement.clip)
    }

    static func expandedSize(for clip: Clip?) -> CGSize {
        guard let clip else { return defaultSize }
        if clip.type == .image {
            return CGSize(width: 300, height: 260)
        }

        let count = max(clip.content.count, 1)
        let lines = clip.content.components(separatedBy: .newlines).count
        let estimatedWrappedLines = max(lines, Int((Double(count) / 32.0).rounded(.up)))
        let height = min(max(CGFloat(estimatedWrappedLines) * 20 + 34, defaultSize.height), 420)
        let width: CGFloat = count > 220 ? 300 : 260
        return CGSize(width: width, height: height)
    }

    private static func isExpanded(_ placement: CanvasPlacement) -> Bool {
        abs(placement.width - defaultSize.width) > 1 || abs(placement.height - defaultSize.height) > 1
    }
}
