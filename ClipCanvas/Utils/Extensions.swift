import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Comparable

extension Comparable {
    /// Clamps a value to a closed range. Defined here to shadow the package-level
    /// SDK symbol of the same name added in iOS 26.
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - CGSize

extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    static func += (lhs: inout CGSize, rhs: CGSize) { lhs = lhs + rhs }
}

// MARK: - View

extension View {
    /// Applies a modifier only when the condition is true.
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Color (UIKit platforms)

#if canImport(UIKit)
extension Color {
    /// Creates a color that adapts between light and dark mode.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor(dynamicProvider: { $0.userInterfaceStyle == .dark ? dark : light }))
    }
}
#endif
