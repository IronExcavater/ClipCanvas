import SwiftUI

enum AppSymbol {
    static let sidebar = "rectangle.leadinghalf.inset.filled"
    static let options = "ellipsis"
    static let settings = "slider.horizontal.3"
}

struct BlendedIconButtonStyle: ButtonStyle {
    let size: CGFloat

    init(size: CGFloat = 46) {
        self.size = size
    }

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

private struct BlendedIconButtonBackground: ViewModifier {
    let isPressed: Bool
    let size: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Circle())
            .shadow(color: .black.opacity(isPressed ? 0.08 : 0.14), radius: isPressed ? 5 : 10, y: isPressed ? 2 : 5)
    }
}

struct AppCircleIconLabel: View {
    let systemImage: String
    var size: CGFloat = 46
    var symbolSize: CGFloat = 18

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}

struct AppToolbarCircleLabel: View {
    let systemImage: String
    var size: CGFloat = 40
    var symbolSize: CGFloat = 16

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Circle())
            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
            .contentShape(Circle())
    }
}

struct AppToolbarCircleButton: View {
    let systemImage: String
    var size: CGFloat = 40
    var symbolSize: CGFloat = 16
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            AppToolbarCircleLabel(systemImage: systemImage, size: size, symbolSize: symbolSize)
        }
        .buttonStyle(.plain)
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

enum AppTagPillSize {
    case compact
    case regular

    var circle: CGFloat { self == .compact ? 16 : 22 }
    var icon: CGFloat { self == .compact ? 7 : 10 }
    var horizontalPadding: CGFloat { self == .compact ? 8 : 12 }
    var verticalPadding: CGFloat { self == .compact ? 5 : 8 }
    var font: Font { self == .compact ? .caption2.weight(.semibold) : .caption.weight(.semibold) }
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
                Circle()
                    .fill(color)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size.icon, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size.circle, height: size.circle)
            Text(title)
                .font(size.font)
                .lineLimit(1)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .foregroundStyle(.primary)
        .background(background, in: Capsule())
        .shadow(color: color.opacity(isSelected ? 0.18 : 0), radius: isSelected ? 6 : 0, y: 2)
    }

    private var background: Color {
        isSelected ? color.opacity(0.30) : color.opacity(0.17)
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
                .background {
                    AppListItemBackground(tint: tint, opacity: opacity)
                }
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
            .background {
                AppListItemBackground(tint: tint, opacity: opacity)
            }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
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
            if isSelecting {
                Text("\(selectedCount) selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Spacer(minLength: 8)

            if isSelecting {
                actions
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if isSelecting {
                Button(action: onToggle) {
                    Label("Done", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                }
                .appSelectionButtonStyle()
            } else {
                Button(action: onToggle) {
                    Image(systemName: "checklist")
                        .font(.system(size: 16, weight: .semibold))
                }
                .appSelectionIconButtonStyle()
            }
        }
        .padding(.horizontal, 2)
        .frame(minHeight: 36)
        .animation(.easeInOut(duration: 0.18), value: isSelecting)
        .animation(.easeInOut(duration: 0.18), value: selectedCount)
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
            searchField
                .layoutPriority(1)

            if isSelecting {
                actions
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))

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
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
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
    @ViewBuilder
    func appInlineNavigationTitleDisplayMode() -> some View {
        #if canImport(UIKit)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appScrollDismissesKeyboardInteractively() -> some View {
        #if canImport(UIKit)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appSheetPresentationDetents() -> some View {
        #if canImport(UIKit)
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appSearchable(text: Binding<String>, isPresented: Binding<Bool>, prompt: String) -> some View {
        #if canImport(UIKit)
        self.searchable(
            text: text,
            isPresented: isPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(prompt)
        )
        #else
        self.searchable(text: text, prompt: Text(prompt))
        #endif
    }

    @ViewBuilder
    func appListSectionSpacingCompact() -> some View {
        #if canImport(UIKit)
        self.listSectionSpacing(.compact)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appHideNavigationBarIfAvailable() -> some View {
        #if canImport(UIKit)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    func appListCard(tint: Color, opacity: Double = 0.10) -> some View {
        AppListItemContainer(tint: tint, opacity: opacity) {
            self
        }
    }

    func appListItemRowInsets(horizontal: CGFloat = 6, vertical: CGFloat = 2) -> some View {
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
        self
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    @ViewBuilder
    func appSelectionIconButtonStyle() -> some View {
        self
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 36, height: 36)
            .background(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground), in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}
