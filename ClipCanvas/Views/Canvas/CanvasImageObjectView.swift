import SwiftUI

struct CanvasImageObjectView: View {
    let clip: Clip
    let isSelected: Bool
    var showsContent = true
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onResize: (CGSize) -> Void
    let onResizeEnded: () -> Void
    let onToggleExpandedSize: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content

            CanvasResizeHandle(
                onResize: onResize,
                onResizeEnded: onResizeEnded,
                onToggleExpandedSize: onToggleExpandedSize
            )
        }
        .background(Color.platformSystemBackground.opacity(0.30), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: isSelected ? 2.5 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08), radius: isSelected ? 10 : 5, y: isSelected ? 4 : 2)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .gesture(tapGesture)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isSelected)
    }

    @ViewBuilder
    private var content: some View {
        if !showsContent {
            Color.clear
        } else if let data = clip.imageData, let image = PlatformImage(data: data) {
            platformImage(image)
        } else {
            Label("Image", systemImage: "photo")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func platformImage(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.04))
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.04))
        #endif
    }

    private var tapGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    onDoubleTap()
                case .second:
                    onTap()
                }
            }
    }
}
