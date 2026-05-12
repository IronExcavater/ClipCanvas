import Foundation
import SwiftUI
import UIKit

// MARK: - Comparable

extension Comparable {
    /// Clamps a value to a closed range. Defined in this module to shadow the
    /// package-level SDK symbol of the same name introduced in iOS 26.
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - CGSize

extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs = lhs + rhs
    }
}

// MARK: - View

extension View {
    /// Applies a modifier only when the condition is true.
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Color

extension Color {
    /// Creates a color that adapts between light and dark mode using UIColor's dynamic provider.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor(dynamicProvider: { $0.userInterfaceStyle == .dark ? dark : light }))
    }
}
