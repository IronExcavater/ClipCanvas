import SwiftUI

struct CanvasTagPanel: View {
    let clips: [Clip]
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
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
                        .padding(.bottom, 10)
                }
                .frame(maxHeight: 320)
                .scrollDismissesKeyboard(.interactively)
            }
            .padding(14)
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
            .padding(.horizontal, 14)
            .padding(.bottom, 96)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
