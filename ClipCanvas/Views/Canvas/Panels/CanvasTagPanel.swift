import SwiftUI

struct CanvasTagPanel: View {
    let clips: [Clip]
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(clips.count > 1 ? "\(clips.count) clips selected" : "Tags")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)

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
            .glassPanel(cornerRadius: 26)
            .padding(.horizontal, 18)
            .padding(.bottom, 92)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
