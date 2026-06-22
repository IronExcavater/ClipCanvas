import SwiftUI

private struct AppListItemBackground: View {
    let tint: Color
    let opacity: Double

    var body: some View {
        ZStack {
            AppGlassSurface(
                shape: .rect(cornerRadius: 14),
                tint: Color.platformSystemBackground.opacity(0.16),
                fallback: .color(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground).opacity(0.88)),
                stroke: Color.primary.opacity(0.05)
            )
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(min(max(opacity, 0.02), 0.045)))
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
                actions
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }

            SelectionModeToggleButton(
                isSelecting: isSelecting,
                selectedCount: selectedCount,
                onBeginSelection: onBeginSelection,
                onEndSelection: onEndSelection
            )
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
        .glassCapsule(shadow: false, interactive: true)
    }
}

private struct SelectionModeToggleButton: View {
    let isSelecting: Bool
    let selectedCount: Int
    let onBeginSelection: () -> Void
    let onEndSelection: () -> Void

    var body: some View {
        Button(action: isSelecting ? onEndSelection : onBeginSelection) {
            Image(systemName: isSelecting ? "checkmark" : "checklist")
                .font(.system(size: isSelecting ? 15 : 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background {
                    AppGlassSurface(
                        shape: .circle,
                        fallback: .color(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground))
                    )
                }
                .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace))
                .overlay(alignment: .topTrailing) {
                    if isSelecting, selectedCount > 0 {
                        Text("\(selectedCount)")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.accentColor, in: Capsule())
                            .offset(x: 3, y: -3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelecting ? "Done" : "Select")
    }
}

struct AppListEmptyState: View {
    let isSourceEmpty: Bool
    let searchText: String
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        Group {
            if isSourceEmpty {
                ContentUnavailableView(
                    title,
                    systemImage: systemImage,
                    description: Text(description)
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .appEmptyStateRow()
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

/// Shared list item row used by clipboard, workspace, trash, and chat lists.
struct AppListRowHeader: View {
    @Environment(\.appListRowIsSelecting) private var isSelecting
    @Environment(\.appListRowIsSelected) private var isSelected
    @ObservedObject private var revealStore = SensitiveTextRevealStore.shared

    let systemImage: String
    let color: Color
    let title: String
    var subtitle: String? = nil
    var metadata: [AppListRowMetadata] = []
    var lineLimit: Int = 1
    var pinned = false
    var date: Date?
    var dateSuffix = " ago"
    var datePrefix = ""
    var dateEmptyText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                leadingIcon
                    .padding(.top, 1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    MarkdownPreview(
                        text: title,
                        revealedSensitiveParts: revealStore.revealedPartIDs,
                        onSensitivePartTapped: revealStore.toggle
                    )
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(lineLimit)
                        .foregroundStyle(.primary)

                    if pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(color)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let subtitle, !subtitle.isEmpty {
                MarkdownPreview(
                    text: subtitle,
                    revealedSensitiveParts: revealStore.revealedPartIDs,
                    onSensitivePartTapped: revealStore.toggle
                )
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.76))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasMetadata {
                metadataRow
            }
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if isSelecting {
            SelectionIndicator(isSelected: isSelected, tint: color)
                .frame(width: 22, height: 22)
        } else {
            AppIconBadge(systemImage: systemImage, color: color)
        }
    }

    private var hasMetadata: Bool {
        !metadata.isEmpty || date != nil
    }

    private var metadataRow: some View {
        HStack(spacing: 12) {
            ForEach(metadata) { item in
                HStack(spacing: 2) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                    Text(item.value)
                        .font(item.monospaced ? .caption2.weight(.semibold).monospacedDigit() : .caption2.weight(.semibold))
                }
            }

            Spacer(minLength: 0)

            if let date {
                RelativeAgeText(date: date, prefix: datePrefix, suffix: dateSuffix, emptyText: dateEmptyText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.52))
            }
        }
        .foregroundStyle(.primary.opacity(0.62))
    }
}

struct AppListRowMetadata: Identifiable, Equatable {
    let systemImage: String
    let value: String
    var monospaced = false

    var id: String { "\(systemImage)|\(value)|\(monospaced)" }

    init(_ systemImage: String, value: String, monospaced: Bool = false) {
        self.systemImage = systemImage
        self.value = value
        self.monospaced = monospaced
    }
}
