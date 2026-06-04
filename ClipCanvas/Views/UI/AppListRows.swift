import SwiftUI

private struct AppListItemBackground: View {
    let tint: Color
    let opacity: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.88))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(max(opacity, 0.14)))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.platformSystemBackground.opacity(0.18))
        }
    }
}

struct AppSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }
}

struct AppListItemButton<Content: View>: View {
    let tint: Color
    var opacity: Double = 0.10
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { AppListItemBackground(tint: tint, opacity: opacity) }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppListItemContainer<Content: View>: View {
    let tint: Color
    var opacity: Double = 0.10
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { AppListItemBackground(tint: tint, opacity: opacity) }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppSearchSelectionBar<Actions: View>: View {
    @Binding var search: String
    let prompt: String
    let isSelecting: Bool
    let selectedCount: Int
    let onBeginSelection: () -> Void
    let onEndSelection: () -> Void
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 9) {
            searchField.layoutPriority(1)

            if isSelecting {
                actions.transition(.opacity.combined(with: .scale(scale: 0.94)))

                Button(action: onEndSelection) {
                    AppToolbarCircleLabel(systemImage: "checkmark", size: 40, symbolSize: 15)
                        .overlay(alignment: .topTrailing) {
                            if selectedCount > 0 {
                                Text("\(selectedCount)")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.accentColor, in: Capsule())
                                    .offset(x: 3, y: -3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            } else {
                Button(action: onBeginSelection) {
                    AppToolbarCircleLabel(systemImage: "checklist", size: 40, symbolSize: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSelecting)
        .animation(.easeInOut(duration: 0.18), value: selectedCount)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $search)
                .textFieldStyle(.plain)
                .submitLabel(.search)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct VerticalEdgeFadeMask: View {
    var top: CGFloat = 12
    var bottom: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: top)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: bottom)
        }
    }
}

struct RelativeAgeText: View {
    let date: Date
    var prefix = ""
    var suffix = ""
    var emptyText = ""

    var body: some View {
        TimelineView(RelativeAgeTimelineSchedule(date: date)) { context in
            let age = RelativeAgeFormatter.shortString(since: date, now: context.date)
            if let text = displayText(for: age) { Text(text) }
        }
    }

    private func displayText(for age: String) -> String? {
        if age.isEmpty {
            if !emptyText.isEmpty { return emptyText }
            if !prefix.isEmpty || !suffix.isEmpty { return "\(prefix)now" }
            return nil
        }
        return "\(prefix)\(age)\(suffix)"
    }
}

private struct RelativeAgeTimelineSchedule: TimelineSchedule {
    let date: Date
    func entries(from startDate: Date, mode: Mode) -> RelativeAgeTimelineEntries {
        RelativeAgeTimelineEntries(sourceDate: date, currentDate: startDate)
    }
}

private struct RelativeAgeTimelineEntries: Sequence, IteratorProtocol {
    let sourceDate: Date
    var currentDate: Date

    mutating func next() -> Date? {
        let date = currentDate
        currentDate = currentDate.addingTimeInterval(
            RelativeAgeFormatter.refreshInterval(since: sourceDate, now: date)
        )
        return date
    }
}

// MARK: - Shared list row header

/// Shared header row used by ClipRow and TrashItemRow (icon + title + optional pin + date).
struct AppListRowHeader: View {
    let systemImage: String
    let color: Color
    let title: String
    var lineLimit: Int = 1
    var pinned = false
    var date: Date?
    var dateSuffix = " ago"
    var datePrefix = ""
    var dateEmptyText = ""

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            AppIconBadge(systemImage: systemImage, color: color)
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(lineLimit)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
            }
            if let date {
                RelativeAgeText(date: date, prefix: datePrefix, suffix: dateSuffix, emptyText: dateEmptyText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.58))
            }
        }
    }
}
