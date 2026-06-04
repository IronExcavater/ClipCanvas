import Foundation
import SwiftUI

struct CanvasResizeSession: Equatable {
    let objectID: UUID
    let startSize: CGSize
    var translation: CGSize

    func proposedSize(scale: CGFloat) -> CGSize {
        let safeScale = max(scale, 0.001)
        return CGSize(
            width: startSize.width + translation.width / safeScale,
            height: startSize.height + translation.height / safeScale
        )
    }
}

struct CanvasResizeHandle: View {
    let onResize: (CGSize) -> Void
    let onResizeEnded: () -> Void
    let onToggleExpandedSize: () -> Void

    var body: some View {
        ResizeHandle()
            .onTapGesture(count: 2, perform: onToggleExpandedSize)
            .highPriorityGesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                    .onChanged { onResize($0.translation) }
                    .onEnded { _ in onResizeEnded() }
            )
    }
}
