import SwiftUI

struct CanvasTagPanel: View {
    let clips: [Clip]
    let onDismiss: () -> Void

    var body: some View {
        CanvasOverlayPanel(
            title: clips.count > 1 ? "\(clips.count) clips selected" : "Tags",
            systemImage: "tag",
            onDismiss: onDismiss
        ) {
            ScrollView {
                ClipTagEditor(clips: clips, layout: .twoColumns)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .scrollClipDisabled()
            .frame(maxHeight: 220)
            .appScrollDismissesKeyboardInteractively()
        }
    }
}
