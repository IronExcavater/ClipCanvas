import SwiftUI
import UIKit

struct ClipCard: View {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(14)

            resizeHandle
        }
        .background {
            cardSurface
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.09), radius: isSelected ? 10 : 6, y: isSelected ? 4 : 2)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(perform: onTap)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isSelected)
    }

    private var content: some View {
        Group {
            if !showsContent {
                Color.clear
            } else if clip.type == .image, let data = clip.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Text(clip.preview.isEmpty ? " " : clip.preview)
                    .font(.system(size: 15))
                    .lineLimit(nil)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var resizeHandle: some View {
        ResizeHandle()
            .onTapGesture(count: 2, perform: onToggleExpandedSize)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { onResize($0.translation) }
                    .onEnded { _ in onResizeEnded() }
            )
    }

    private var cardSurface: some View {
        ZStack {
            Color.adaptive(light: .white, dark: UIColor.secondarySystemBackground)
            primaryColor.opacity(0.24)
        }
    }

    private var primaryColor: Color {
        if let tag = clip.tags.min(by: { $0.sortIndex < $1.sortIndex }) {
            return tag.color
        }
        return clip.color.background
    }
}

private struct ResizeHandle: View {
    var body: some View {
        Canvas { ctx, size in
            let count = 3
            let spacing: CGFloat = 6
            let lineWidth: CGFloat = 1.5
            for i in 0..<count {
                let offset = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: size.width - offset - spacing, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height - offset - spacing))
                ctx.stroke(path, with: .color(.secondary.opacity(0.55)), lineWidth: lineWidth)
            }
        }
        .frame(width: 28, height: 28)
        .padding(6)
        .contentShape(Rectangle())
    }
}

extension CardColor {
    var background: Color {
        switch self {
        case .cloud:    return .adaptive(light: UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1), dark: UIColor(red: 0.22, green: 0.22, blue: 0.21, alpha: 1))
        case .banana:   return .adaptive(light: UIColor(red: 1.00, green: 0.95, blue: 0.46, alpha: 1), dark: UIColor(red: 0.42, green: 0.38, blue: 0.03, alpha: 1))
        case .flamingo: return .adaptive(light: UIColor(red: 1.00, green: 0.67, blue: 0.67, alpha: 1), dark: UIColor(red: 0.50, green: 0.17, blue: 0.17, alpha: 1))
        case .sage:     return .adaptive(light: UIColor(red: 0.71, green: 0.92, blue: 0.84, alpha: 1), dark: UIColor(red: 0.10, green: 0.36, blue: 0.26, alpha: 1))
        case .sky:      return .adaptive(light: UIColor(red: 0.68, green: 0.84, blue: 0.95, alpha: 1), dark: UIColor(red: 0.10, green: 0.29, blue: 0.44, alpha: 1))
        case .lavender: return .adaptive(light: UIColor(red: 0.84, green: 0.74, blue: 0.89, alpha: 1), dark: UIColor(red: 0.30, green: 0.18, blue: 0.40, alpha: 1))
        case .peach:    return .adaptive(light: UIColor(red: 1.00, green: 0.85, blue: 0.76, alpha: 1), dark: UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 1))
        }
    }
}
