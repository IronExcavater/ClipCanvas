import SwiftUI

/// Base shell for every list item row in the app.
///
/// Handles: tinted card background, optional selection circle, draggable support,
/// and the standard list row modifiers (no separator, clear background).
/// Callers add their own tap gestures, swipe actions, and context menus on top.
struct ItemRow<Content: View>: View {
    var tint: Color = .secondary
    var opacity: Double = 0.12
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var dragID: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        let card = AppListItemContainer(tint: tint, opacity: opacity) {
            content
                .environment(\.appListRowIsSelecting, isSelecting)
                .environment(\.appListRowIsSelected, isSelected)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())

        if let dragID {
            card.draggable(dragID)
        } else {
            card
        }
    }
}

private struct AppListRowIsSelectingKey: EnvironmentKey {
    static let defaultValue = false
}

private struct AppListRowIsSelectedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appListRowIsSelecting: Bool {
        get { self[AppListRowIsSelectingKey.self] }
        set { self[AppListRowIsSelectingKey.self] = newValue }
    }

    var appListRowIsSelected: Bool {
        get { self[AppListRowIsSelectedKey.self] }
        set { self[AppListRowIsSelectedKey.self] = newValue }
    }
}

/// A selection checkbox used inside ItemRow when multi-select is active.
struct SelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
