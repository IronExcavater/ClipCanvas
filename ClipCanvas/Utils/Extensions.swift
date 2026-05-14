import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#endif

#if canImport(AppKit)
extension NSColor {
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var label: NSColor { .labelColor }
}
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

// MARK: - Color

#if canImport(UIKit)
extension Color {
    /// Creates a color that adapts between light and dark mode.
    static func adaptive(light: PlatformColor, dark: PlatformColor) -> Color {
        Color(UIColor(dynamicProvider: { $0.userInterfaceStyle == .dark ? dark : light }))
    }

    static var platformSystemBackground: Color { Color(uiColor: .systemBackground) }
    static var platformSecondarySystemBackground: Color { Color(uiColor: .secondarySystemBackground) }
    init(platformColor: PlatformColor) { self.init(uiColor: platformColor) }
}
#elseif canImport(AppKit)
extension Color {
    static func adaptive(light: PlatformColor, dark: PlatformColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let best = appearance.bestMatch(from: [.darkAqua, .aqua])
            return best == .darkAqua ? dark : light
        })
    }

    static var platformSystemBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var platformSecondarySystemBackground: Color { Color(nsColor: .controlBackgroundColor) }
    init(platformColor: PlatformColor) { self.init(nsColor: platformColor) }
}
#endif
