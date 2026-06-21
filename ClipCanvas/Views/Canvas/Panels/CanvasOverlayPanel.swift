import SwiftUI

struct CanvasOverlayPanel<Content: View>: View {
    var title: String?
    var systemImage: String?
    var showsDragIndicator = true
    var onDismiss: (() -> Void)?
    var maxWidth: CGFloat = 420
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        systemImage: String? = nil,
        showsDragIndicator: Bool = true,
        maxWidth: CGFloat = 420,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.showsDragIndicator = showsDragIndicator
        self.maxWidth = maxWidth
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            if showsDragIndicator {
                Capsule()
                    .fill(Color.primary.opacity(0.20))
                    .frame(width: 38, height: 5)
                    .padding(.top, 2)
            }

            if title != nil || onDismiss != nil {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }

                    if let title {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    if let onDismiss {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                }
            }

            content
        }
        .padding(12)
        .frame(maxWidth: maxWidth)
        .glassPanel(cornerRadius: 26, interactive: true)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct CanvasBottomOverlay<Content: View>: View {
    var horizontalPadding: CGFloat = 18
    var bottomPadding: CGFloat = 92
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    init(
        horizontalPadding: CGFloat = 18,
        bottomPadding: CGFloat = 92,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            content
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
