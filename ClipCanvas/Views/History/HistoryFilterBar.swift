import SwiftUI
import SwiftData

struct HistoryFilterBar: View {
    var filter: HistoryFilter

    @Query(sort: \ClipTag.sortIndex) private var tags: [ClipTag]

    private var userTags: [ClipTag] {
        tags.filter { !$0.isBuiltIn }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: "All", color: .secondary, icon: "tray.full")
                ForEach(ClipType.allCases, id: \.self) { type in
                    chip(
                        .builtIn(type),
                        label: ClipTag.builtInName(for: type),
                        color: ClipTag.builtInColor(for: type),
                        icon: type.icon
                    )
                }
                ForEach(userTags) { tag in
                    chip(.user(tag.id), label: tag.name, color: tag.color, icon: "tag")
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func chip(_ tag: HistoryTagFilter?, label: String, color: Color, icon: String) -> some View {
        let active = filter.tag == tag
        return Button {
            filter.tag = active ? nil : tag
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((active ? color : color.opacity(0.16)), in: Capsule())
            .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
