import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ClipCard: View {
    let clip: Clip
    var fillColor: Color?
    var isTransparentSurface = false
    let isSelected: Bool
    var showsContent = true
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    var isEditing = false
    var editingText = ""
    var fontSize: CGFloat = 15
    var textCommand: NoteTextCommand?
    let onCommitEditing: (String) -> Void
    var onExitEditing: () -> Void = {}
    var onEditorSizeChange: (CGSize) -> Void = { _ in }
    let onResize: (CGSize) -> Void
    let onResizeEnded: () -> Void
    let onToggleExpandedSize: () -> Void

    @ObservedObject private var revealStore = SensitiveTextRevealStore.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, clip.tags.isEmpty ? 14 : 36)

            if !clip.tags.isEmpty {
                CanvasNoteTagFooter(tags: Array(clip.tags.sorted { $0.sortIndex < $1.sortIndex }.prefix(3)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
                    .padding(.trailing, 42)
            }

            if !isEditing {
                resizeHandle
            }

        }
        .background {
            cardSurface
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .shadow(
            color: .black.opacity(isTransparentSurface ? 0 : (isSelected ? 0.16 : 0.09)),
            radius: isTransparentSurface ? 0 : (isSelected ? 10 : 6),
            y: isTransparentSurface ? 0 : (isSelected ? 4 : 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gesture(tapGesture)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isSelected)
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

    private var content: some View {
        Group {
            if !showsContent {
                Color.clear
            } else if isEditing, clip.type != .image {
                NoteTextEditor(
                    initialText: editingText,
                    fontSize: fontSize,
                    command: textCommand,
                    onCommit: onCommitEditing,
                    onExitEditing: onExitEditing,
                    onSizeChange: onEditorSizeChange
                )
            } else if clip.type == .image, let data = clip.imageData, let image = PlatformImage(data: data) {
                platformImage(image)
            } else {
                MarkdownPreview(
                    text: displayPreview.isEmpty ? " " : displayPreview,
                    revealedSensitiveParts: revealStore.revealedPartIDs,
                    onSensitivePartTapped: revealStore.toggle
                )
                    .font(.system(size: fontSize))
                    .lineLimit(nil)
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private func platformImage(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .clipped()
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .clipped()
        #endif
    }

    private var displayPreview: String {
        clip.displayPreview(isRevealed: false)
    }

    private var resizeHandle: some View {
        CanvasResizeHandle(
            onResize: onResize,
            onResizeEnded: onResizeEnded,
            onToggleExpandedSize: onToggleExpandedSize
        )
    }

    private var cardSurface: some View {
        ZStack {
            if isTransparentSurface {
                Color.clear
            } else {
                Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground)
                (fillColor ?? primaryColor).opacity(0.18)
            }
        }
    }

    private var primaryColor: Color {
        return clip.color.background
    }
}

struct CanvasNoteTagFooter: View {
    let tags: [ClipTag]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags) { tag in
                AppTagPill(
                    title: tag.name,
                    color: tag.color,
                    icon: "tag",
                    isSelected: false,
                    size: .compact
                )
            }
        }
    }
}


struct ResizeHandle: View {
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
        case .cloud:    return .adaptive(light: PlatformColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1), dark: PlatformColor(red: 0.22, green: 0.22, blue: 0.21, alpha: 1))
        case .banana:   return .adaptive(light: PlatformColor(red: 1.00, green: 0.95, blue: 0.46, alpha: 1), dark: PlatformColor(red: 0.42, green: 0.38, blue: 0.03, alpha: 1))
        case .flamingo: return .adaptive(light: PlatformColor(red: 1.00, green: 0.67, blue: 0.67, alpha: 1), dark: PlatformColor(red: 0.50, green: 0.17, blue: 0.17, alpha: 1))
        case .sage:     return .adaptive(light: PlatformColor(red: 0.71, green: 0.92, blue: 0.84, alpha: 1), dark: PlatformColor(red: 0.10, green: 0.36, blue: 0.26, alpha: 1))
        case .sky:      return .adaptive(light: PlatformColor(red: 0.68, green: 0.84, blue: 0.95, alpha: 1), dark: PlatformColor(red: 0.10, green: 0.29, blue: 0.44, alpha: 1))
        case .lavender: return .adaptive(light: PlatformColor(red: 0.84, green: 0.74, blue: 0.89, alpha: 1), dark: PlatformColor(red: 0.30, green: 0.18, blue: 0.40, alpha: 1))
        case .peach:    return .adaptive(light: PlatformColor(red: 1.00, green: 0.85, blue: 0.76, alpha: 1), dark: PlatformColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 1))
        }
    }
}
