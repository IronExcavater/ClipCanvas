import SwiftUI
import UIKit

enum AppSymbol {
    static let sidebar = "rectangle.leadinghalf.inset.filled"
    static let options = "ellipsis"
    static let settings = "gearshape"
}

struct BlendedIconButtonStyle: ButtonStyle {
    private let size: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .modifier(BlendedIconButtonBackground(isPressed: configuration.isPressed, size: size))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Circle())
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct BlendedIconCircle<Content: View>: View {
    private let size: CGFloat = 46
    @ViewBuilder var content: Content

    var body: some View {
        content
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .modifier(BlendedIconButtonBackground(isPressed: false, size: size))
            .contentShape(Circle())
    }
}

private struct BlendedIconButtonBackground: ViewModifier {
    let isPressed: Bool
    let size: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(Color(uiColor: .systemBackground).opacity(isPressed ? 0.92 : 0.78), in: Circle())
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: size / 2))
        } else {
            content
                .background(Color(uiColor: .systemBackground), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(isPressed ? 0.16 : 0.08), lineWidth: 1)
                )
        }
    }
}

struct AppDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 4)
    }
}

struct AppActionPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 4) {
            content
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }
}

struct AppActionPanelRow: View {
    let title: String
    let icon: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(destructive ? .red : .primary)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(.horizontal, 10)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AppTagChip: View {
    let title: String
    let color: Color
    var icon: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AppTagPill(title: title, color: color, icon: icon, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct AppTagPill: View {
    let title: String
    let color: Color
    var icon: String?
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(.primary)
        .background(background, in: Capsule())
    }

    private var background: Color {
        isSelected ? color.opacity(0.28) : color.opacity(0.13)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    AppListItemBackground(tint: tint, opacity: opacity)
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AppListItemContainer<Content: View>: View {
    let tint: Color
    var opacity: Double = 0.10
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                AppListItemBackground(tint: tint, opacity: opacity)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AppListSelectionControl<Actions: View>: View {
    let isSelecting: Bool
    let selectedCount: Int
    let selectTitle: String
    let onToggle: () -> Void
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Label(isSelecting ? "Done" : selectTitle, systemImage: isSelecting ? "checkmark.circle.fill" : "checkmark.circle")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelecting ? Color.accentColor : .primary)
                    .padding(.horizontal, 2)
            }
            .appSelectionButtonStyle()

            if isSelecting {
                Text("\(selectedCount) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Spacer(minLength: 8)

            if isSelecting {
                actions
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, 2)
        .frame(minHeight: 44)
        .animation(.easeInOut(duration: 0.18), value: isSelecting)
        .animation(.easeInOut(duration: 0.18), value: selectedCount)
    }
}

private struct AppListItemBackground: View {
    let tint: Color
    let opacity: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(max(opacity, 0.12)))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.28))
        }
    }
}

extension View {
    func appListItemContentPadding(horizontal: CGFloat = 9, vertical: CGFloat = 8) -> some View {
        self.padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
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
            if let text = displayText(for: age) {
                Text(text)
            }
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

extension View {
    func appListCard(tint: Color, opacity: Double = 0.10) -> some View {
        AppListItemContainer(tint: tint, opacity: opacity) {
            self
        }
    }

    func appListItemRowInsets(horizontal: CGFloat = 8, vertical: CGFloat = 3) -> some View {
        self
            .listRowInsets(EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func appEmptyStateRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    @ViewBuilder
    func appSelectionButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            self
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }

    @ViewBuilder
    func appSelectionIconButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            self
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
        }
    }
}
