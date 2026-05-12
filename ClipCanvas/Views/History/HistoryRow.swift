import SwiftUI

struct HistoryRow: View {
    let clip: Clip
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onDetails: () -> Void

    var body: some View {
        ClipRowView(
            clip: clip,
            compact: false,
            onCopy: onCopy,
            onTogglePin: onTogglePin,
            onDelete: onDelete,
            onDetails: onDetails
        )
    }
}
