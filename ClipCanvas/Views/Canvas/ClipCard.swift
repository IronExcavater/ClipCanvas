import SwiftUI

struct ClipCard: View {
    let clip: Clip
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Divider()
                .background(clip.color.dividerColor)
            footer
        }
        .background(clip.color.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(selectionRing)
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.08), radius: isSelected ? 12 : 5, y: isSelected ? 4 : 2)
        .onTapGesture { onTap() }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                ClipboardService.write(clip: clip)
            }

            Menu("Color", systemImage: "paintpalette") {
                ForEach(CardColor.allCases, id: \.self) { color in
                    Button {
                        clip.color = color
                    } label: {
                        Label(color.label, systemImage: clip.color == color ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            }

            Divider()

            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }

    // MARK: - Subviews

    private var content: some View {
        Group {
            if clip.type == .image, let data = clip.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
            } else {
                Text(clip.preview.isEmpty ? " " : clip.preview)
                    .font(.system(size: 13))
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: clip.type.icon)
                .font(.system(size: 10))
            Text(clip.origin.label)
                .font(.system(size: 10))
            Spacer()
            Text(clip.createdAt, style: .relative)
                .font(.system(size: 10))
        }
        .foregroundStyle(clip.color.footerColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var selectionRing: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.accentColor, lineWidth: isSelected ? 2.5 : 0)
    }
}

// MARK: - CardColor visual properties

extension CardColor {
    var background: Color {
        switch self {
        case .cloud:    return Color(red: 0.96, green: 0.96, blue: 0.94)
        case .banana:   return Color(red: 1.00, green: 0.95, blue: 0.46)
        case .flamingo: return Color(red: 1.00, green: 0.67, blue: 0.67)
        case .sage:     return Color(red: 0.71, green: 0.92, blue: 0.84)
        case .sky:      return Color(red: 0.68, green: 0.84, blue: 0.95)
        case .lavender: return Color(red: 0.84, green: 0.74, blue: 0.89)
        case .peach:    return Color(red: 1.00, green: 0.85, blue: 0.76)
        }
    }

    var dividerColor: Color { background.opacity(0.6) }
    var footerColor: Color { Color.black.opacity(0.45) }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ClipCard(
            clip: Clip(content: "Buy oat milk and check the PR before standup tomorrow morning.", origin: .clipboard),
            isSelected: false,
            onTap: {},
            onDelete: {}
        )
        .frame(width: 220)

        ClipCard(
            clip: Clip(content: "https://developer.apple.com/documentation/swiftui", origin: .clipboard),
            isSelected: true,
            onTap: {},
            onDelete: {}
        )
        .frame(width: 220)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
