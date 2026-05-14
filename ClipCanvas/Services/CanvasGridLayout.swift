import CoreGraphics
import Foundation

nonisolated struct CanvasGridLayoutItem<ID: Hashable> {
    let id: ID
    let size: CGSize
}

nonisolated struct CanvasGridLayoutFrame<ID: Hashable>: Equatable {
    let id: ID
    let origin: CGPoint
    let size: CGSize
}

nonisolated enum CanvasGridLayout {
    static let defaultSpacing = CGSize(width: 22, height: 22)

    static func balancedColumnCount(for itemCount: Int) -> Int {
        max(1, Int(ceil(sqrt(Double(itemCount)))))
    }

    static func frames<ID: Hashable>(
        for items: [CanvasGridLayoutItem<ID>],
        columns: Int,
        origin: CGPoint,
        spacing: CGSize = defaultSpacing
    ) -> [CanvasGridLayoutFrame<ID>] {
        guard !items.isEmpty else { return [] }

        let columns = max(1, columns)
        let rows = Int(ceil(Double(items.count) / Double(columns)))
        let columnWidths = columnWidths(for: items, columns: columns)
        let rowHeights = rowHeights(for: items, columns: columns, rows: rows)

        return items.enumerated().map { index, item in
            let column = index % columns
            let row = index / columns
            let xOffset = columnWidths.prefix(column).reduce(0, +) + spacing.width * CGFloat(column)
            let yOffset = rowHeights.prefix(row).reduce(0, +) + spacing.height * CGFloat(row)

            return CanvasGridLayoutFrame(
                id: item.id,
                origin: CGPoint(x: origin.x + xOffset, y: origin.y + yOffset),
                size: item.size
            )
        }
    }

    static func centeredFrames<ID: Hashable>(
        for items: [CanvasGridLayoutItem<ID>],
        columns: Int,
        center: CGPoint,
        spacing: CGSize = defaultSpacing
    ) -> [CanvasGridLayoutFrame<ID>] {
        let size = contentSize(for: items, columns: columns, spacing: spacing)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        return frames(for: items, columns: columns, origin: origin, spacing: spacing)
    }

    static func contentSize<ID: Hashable>(
        for items: [CanvasGridLayoutItem<ID>],
        columns: Int,
        spacing: CGSize = defaultSpacing
    ) -> CGSize {
        guard !items.isEmpty else { return .zero }

        let columns = max(1, columns)
        let rows = Int(ceil(Double(items.count) / Double(columns)))
        let columnWidths = columnWidths(for: items, columns: columns)
        let rowHeights = rowHeights(for: items, columns: columns, rows: rows)

        return CGSize(
            width: columnWidths.reduce(0, +) + spacing.width * CGFloat(max(columns - 1, 0)),
            height: rowHeights.reduce(0, +) + spacing.height * CGFloat(max(rows - 1, 0))
        )
    }

    private static func columnWidths<ID: Hashable>(
        for items: [CanvasGridLayoutItem<ID>],
        columns: Int
    ) -> [CGFloat] {
        var widths = Array(repeating: CGFloat.zero, count: max(1, columns))

        for (index, item) in items.enumerated() {
            let column = index % widths.count
            widths[column] = max(widths[column], item.size.width)
        }

        return widths
    }

    private static func rowHeights<ID: Hashable>(
        for items: [CanvasGridLayoutItem<ID>],
        columns: Int,
        rows: Int
    ) -> [CGFloat] {
        var heights = Array(repeating: CGFloat.zero, count: max(1, rows))

        for (index, item) in items.enumerated() {
            let row = index / max(1, columns)
            heights[row] = max(heights[row], item.size.height)
        }

        return heights
    }
}
