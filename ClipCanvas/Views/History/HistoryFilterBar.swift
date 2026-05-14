import SwiftUI
import SwiftData

struct HistoryFilterBar: View {
    var filter: HistoryFilter

    @Query(sort: \ClipTag.sortIndex) private var tags: [ClipTag]

    private var userTags: [ClipTag] {
        tags.filter { !$0.isBuiltIn }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            fadingFilterRow {
                ForEach(ClipType.allCases, id: \.self) { type in
                    typeChip(type, label: ClipTag.builtInName(for: type), color: ClipTag.builtInColor(for: type))
                }
            }

            if !userTags.isEmpty {
                fadingFilterRow {
                    ForEach(userTags) { tag in
                        userTagChip(tag.id, label: tag.name, color: tag.color)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func fadingFilterRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6, content: content)
                .padding(.horizontal, 12)
        }
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 6)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 6)
            }
        )
    }

    private func typeChip(_ type: ClipType, label: String, color: Color) -> some View {
        let active = filter.type == type
        return AppTagChip(
            title: label,
            color: color,
            icon: type.icon,
            isSelected: active
        ) {
            filter.type = active ? nil : type
        }
    }

    private func userTagChip(_ tagID: UUID?, label: String, color: Color) -> some View {
        let active = filter.userTagID == tagID
        return AppTagChip(
            title: label,
            color: color,
            icon: "tag",
            isSelected: active
        ) {
            filter.userTagID = active ? nil : tagID
        }
    }
}
