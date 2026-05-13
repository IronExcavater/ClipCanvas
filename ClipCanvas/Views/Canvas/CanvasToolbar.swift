import SwiftUI

struct CanvasToolbar: View {
    @Binding var mode: CanvasMode
    let selectedCount: Int
    let canOpenLink: Bool
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onOpenLink: () -> Void
    let onDetails: () -> Void
    let onDelete: () -> Void
    let onArrangeSelection: () -> Void
    let onManageTags: () -> Void

    private var hasSelection: Bool { selectedCount > 0 }
    private var configuration: CanvasToolbarConfiguration {
        CanvasToolbarConfiguration.make(selectedCount: selectedCount, canOpenLink: canOpenLink)
    }
    private let buttonSize: CGFloat = 52
    private let iconSize: CGFloat = 19

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(configuration.items.enumerated()), id: \.offset) { _, item in
                toolbarItem(item)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            toolbarBackground
        }
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: hasSelection ? 420 : 300)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private func toolbarItem(_ item: CanvasToolbarItem) -> some View {
        switch item {
        case .paste:
            toolButton("doc.on.clipboard", action: onPaste)
        case .copy:
            toolButton("doc.on.doc", action: onCopy)
        case .openLink:
            toolButton("safari", action: onOpenLink)
        case .details:
            toolButton("info.circle", action: onDetails)
                .disabled(selectedCount != 1)
                .opacity(selectedCount == 1 ? 1 : 0.42)
        case .manageTags:
            toolButton("tag", action: onManageTags)
        case .arrangeSelection:
            toolButton("square.grid.2x2", action: onArrangeSelection)
        case .delete:
            destructiveButton("trash", action: onDelete)
        case .divider:
            AppDivider()
        case .mode(let canvasMode):
            modeButton(canvasMode.systemImage, for: canvasMode)
        }
    }

    private func modeButton(_ icon: String, for target: CanvasMode) -> some View {
        Button { mode = target } label: {
            let selected = mode == target
            ZStack {
                Circle()
                    .fill(selected ? Color.accentColor : Color.clear)
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(selected ? .white : .primary)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
            .shadow(
                color: selected ? Color.accentColor.opacity(0.28) : .clear,
                radius: selected ? 9 : 0,
                y: selected ? 4 : 0
            )
            .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: mode == target)
    }

    private func toolButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Color.clear
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func destructiveButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            ZStack {
                Color.clear
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var toolbarBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 36))
        } else {
            Capsule()
                .fill(.regularMaterial)
        }
    }
}

struct CanvasZoomControls: View {
    let scale: CGFloat
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            zoomButton("plus", action: onZoomIn)
            Text("\(Int((scale * 100).rounded()))%")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 38, height: 18)
            zoomButton("minus", action: onZoomOut)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .frame(width: 44)
        .padding(.vertical, 5)
        .background {
            zoomBackground
        }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func zoomButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
    }

    @ViewBuilder
    private var zoomBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            Capsule()
                .fill(.regularMaterial)
        }
    }
}
