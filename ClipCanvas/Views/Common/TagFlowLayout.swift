import SwiftUI

struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if cursor.x > 0, cursor.x + size.width > maxWidth {
                cursor.x = 0
                cursor.y += rowHeight + rowSpacing
                rowHeight = 0
            }
            measuredWidth = max(measuredWidth, cursor.x + size.width)
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: cursor.y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursor = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if cursor.x > bounds.minX, cursor.x + size.width > bounds.maxX {
                cursor.x = bounds.minX
                cursor.y += rowHeight + rowSpacing
                rowHeight = 0
            }
            subview.place(
                at: cursor,
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
