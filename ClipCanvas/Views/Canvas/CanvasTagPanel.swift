import SwiftUI

struct CanvasTagPanel: View {
    let clips: [Clip]
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(clips.count == 1 ? "Tags" : "Tags for \(clips.count)")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(BlendedIconButtonStyle(size: 34))
                    .accessibilityLabel("Close tags")
                }

                ScrollView {
                    ClipTagEditor(clips: clips, layout: .twoColumns)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .padding(.bottom, 6)
                }
                .scrollClipDisabled()
                .frame(maxHeight: 250)
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
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
