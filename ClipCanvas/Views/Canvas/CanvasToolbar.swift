import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let onPaste: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            modeButton(icon: "hand.point.up.left", label: "Pan", for: .pan)
            modeButton(icon: "checkmark.circle", label: "Select", for: .select)
            modeButton(icon: "pencil.tip", label: "Draw", for: .draw)

            Spacer()

            Button(action: onPaste) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .medium))
                    Text("Paste")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(.accentColor)
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.regularMaterial)
    }

    private func modeButton(icon: String, label: String, for target: CanvasMode) -> some View {
        Button {
            mode = target
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(mode == target ? Color.accentColor : Color.secondary)
            .frame(width: 58, height: 46)
            .background(
                mode == target ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }
}
