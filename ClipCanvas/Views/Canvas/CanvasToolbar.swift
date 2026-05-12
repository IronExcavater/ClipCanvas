import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let onPaste: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFitContent: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            toolButton("doc.on.clipboard", action: onPaste)

            divider

            modeButton("hand.point.up.left", for: .pan)
            modeButton("pencil.tip", for: .draw)

            Spacer(minLength: 10)

            zoomControl
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            toolbarBackground
                .clipShape(Capsule())
        }
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
    }

    private func modeButton(_ icon: String, for target: CanvasMode) -> some View {
        Button { mode = target } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(mode == target ? .white : .primary)
                .frame(width: 46, height: 46)
                .background(mode == target ? Color.accentColor : Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: mode == target)
    }

    private func toolButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
    }

    private var zoomControl: some View {
        HStack(spacing: 0) {
            Button(action: onZoomOut) {
                Image(systemName: "minus")
                    .frame(width: 38, height: 42)
            }
            Button(action: onFitContent) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 42, height: 42)
            }
            Button(action: onZoomIn) {
                Image(systemName: "plus")
                    .frame(width: 38, height: 42)
            }
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.08), in: Capsule())
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 26)
            .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var toolbarBackground: some View {
        if #available(iOS 26, *) {
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color.clear.background(.regularMaterial)
        }
    }
}
