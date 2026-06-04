import SwiftUI

// MARK: - SelectionState

/// Manages multi-select state for any list of identifiable items.
/// Reduces boilerplate across History, Trash, and Workspaces pages.
struct SelectionState<ID: Hashable> {
    var isActive = false
    var selectedIDs: Set<ID> = []

    var count: Int  { selectedIDs.count }
    var isEmpty: Bool { selectedIDs.isEmpty }

    mutating func begin() {
        selectedIDs.removeAll()
        isActive = true
    }

    mutating func end() {
        selectedIDs.removeAll()
        isActive = false
    }

    mutating func toggle(_ id: ID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func contains(_ id: ID) -> Bool { selectedIDs.contains(id) }
}

// MARK: - Animated search binding

extension Binding where Value == String {
    /// A binding that applies a standard ease-in-out animation to every write.
    /// Use instead of the repeated Binding { withAnimation { search = $0 } } boilerplate.
    var withListAnimation: Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { newValue in withAnimation(.easeInOut(duration: 0.18)) { wrappedValue = newValue } }
        )
    }
}

// MARK: - Page list style

extension View {
    /// Standard styling for the full-screen List used on History, Trash, and Workspaces pages.
    func appPageListStyle() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
    }

    /// Standard toolbar options button (ellipsis circle) used on list pages.
    func appPageToolbarOptions<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu(content: { self }, label: label)
            }
        }
    }
}
