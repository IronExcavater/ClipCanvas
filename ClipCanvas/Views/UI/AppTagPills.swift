import SwiftUI

enum AppTagPillSize {
    case compact
    case regular

    var circle: CGFloat          { self == .compact ? 16 : 22 }
    var icon: CGFloat            { self == .compact ? 7 : 10 }
    var horizontalPadding: CGFloat { self == .compact ? 8 : 12 }
    var verticalPadding: CGFloat { self == .compact ? 5 : 8 }
    var font: Font               { self == .compact ? .caption2.weight(.semibold) : .caption.weight(.semibold) }
}

struct AppTagPill: View {
    let title: String
    let color: Color
    var icon: String?
    var isSelected: Bool
    var size: AppTagPillSize = .regular

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(color)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size.icon, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size.circle, height: size.circle)
            Text(title).font(size.font).lineLimit(1)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .foregroundStyle(.primary)
        .background(isSelected ? color.opacity(0.30) : color.opacity(0.17), in: Capsule())
        .shadow(color: color.opacity(isSelected ? 0.18 : 0), radius: isSelected ? 6 : 0, y: 2)
    }
}

struct AppTagChip: View {
    let title: String
    let color: Color
    var icon: String?
    var isSelected: Bool
    var size: AppTagPillSize = .regular
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AppTagPill(title: title, color: color, icon: icon, isSelected: isSelected, size: size)
        }
        .buttonStyle(.plain)
    }
}

/// A horizontal row of tag pills — used in ClipRow, TrashItemRow, and CanvasNoteTagFooter.
/// Sorts by sortIndex, caps at `limit`, and renders nothing when the array is empty.
struct TagPillRow: View {
    let tags: [ClipTag]
    var limit: Int = 3
    var size: AppTagPillSize = .compact

    var body: some View {
        let displayed = Array(tags.sorted { $0.sortIndex < $1.sortIndex }.prefix(limit))
        if !displayed.isEmpty {
            HStack(spacing: 5) {
                ForEach(displayed) { tag in
                    AppTagPill(title: tag.name, color: tag.color, icon: "tag", isSelected: false, size: size)
                }
            }
        }
    }
}
