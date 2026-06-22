import CoreGraphics
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

    private let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            CanvasResizeHandle(
                onResize: onResize,
                onResizeEnded: onResizeEnded,
                onToggleExpandedSize: onToggleExpandedSize,
                tint: resizeHandleTint
            )
            .padding(5)
        }
        .background(Color.platformSystemBackground.opacity(0.30), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08), radius: isSelected ? 10 : 5, y: isSelected ? 4 : 2)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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

    private var resizeHandleTint: Color {
        guard let data = clip.imageData,
              let image = PlatformImage(data: data),
              let luminance = bottomTrailingLuminance(of: image) else {
            return .white
        }
        return luminance < 0.48 ? .white : .black
    }

    private func bottomTrailingLuminance(of image: PlatformImage) -> CGFloat? {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return nil }
        #elseif canImport(AppKit)
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        #else
        return nil
        #endif

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data),
              cgImage.bitsPerPixel >= 24 else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 3)
        let bytesPerRow = cgImage.bytesPerRow
        let startX = Int(CGFloat(width) * 0.66)
        let startY = Int(CGFloat(height) * 0.66)
        let xStep = max((width - startX) / 12, 1)
        let yStep = max((height - startY) / 12, 1)

        var total: CGFloat = 0
        var count: CGFloat = 0

        var y = startY
        while y < height {
            var x = startX
            while x < width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard offset + 2 < CFDataGetLength(data) else {
                    x += xStep
                    continue
                }
                let red = CGFloat(bytes[offset]) / 255
                let green = CGFloat(bytes[offset + 1]) / 255
                let blue = CGFloat(bytes[offset + 2]) / 255
                total += red * 0.299 + green * 0.587 + blue * 0.114
                count += 1
                x += xStep
            }
            y += yStep
        }

        guard count > 0 else { return nil }
        return total / count
    }
}
