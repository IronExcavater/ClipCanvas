import SwiftUI

struct CanvasUndoControls: View {
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            hudButton("arrow.uturn.backward", action: onUndo)
            hudButton("arrow.uturn.forward", action: onRedo)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .frame(width: 44)
        .padding(.vertical, 6)
        .glassPanel(cornerRadius: 22, shadow: false)
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func hudButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
    }
}

struct CanvasZoomControls: View {
    let scale: CGFloat
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                hudButton("plus", action: onZoomIn)
                hudButton("minus", action: onZoomOut)
            }
            Text("\(Int((scale * 100).rounded()))%")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .frame(width: 44)
        .padding(.vertical, 5)
        .glassPanel(cornerRadius: 22, shadow: false)
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func hudButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
    }
}
