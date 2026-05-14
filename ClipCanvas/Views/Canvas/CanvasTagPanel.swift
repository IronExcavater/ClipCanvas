import SwiftUI

struct CanvasTagPanel: View {
    let clips: [Clip]
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    ClipTagEditor(clips: clips, layout: .twoColumns)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
                .scrollClipDisabled()
                .frame(maxHeight: 220)
                .appScrollDismissesKeyboardInteractively()
            }
            .padding(12)
            .background {
                if #available(iOS 26, *) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 26))
                } else {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
            .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
            .padding(.horizontal, 18)
            .padding(.bottom, 92)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
