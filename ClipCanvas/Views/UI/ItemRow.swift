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
            HStack(alignment: .top, spacing: 10) {
                if isSelecting {
                    SelectionIndicator(isSelected: isSelected)
                }
                VStack(alignment: .leading, spacing: 4) {
                    content
                }
            }
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

/// A selection checkbox used inside ItemRow when multi-select is active.
struct SelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .padding(.top, 3)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
