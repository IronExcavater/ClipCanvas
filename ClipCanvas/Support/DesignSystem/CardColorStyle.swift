import SwiftUI

extension CardColor {
    var background: Color {
        switch self {
        case .default: .clipCanvasCardBackground
        case .yellow: Color(red: 1.0, green: 0.95, blue: 0.68)
        case .blue: Color(red: 0.74, green: 0.88, blue: 1.0)
        case .green: Color(red: 0.76, green: 0.94, blue: 0.78)
        case .pink: Color(red: 1.0, green: 0.80, blue: 0.88)
        case .purple: Color(red: 0.88, green: 0.80, blue: 0.98)
        }
    }

    var foreground: Color {
        .primary
    }

    var accent: Color {
        switch self {
        case .default: Color.secondary
        case .yellow: Color(red: 0.72, green: 0.54, blue: 0.04)
        case .blue: Color(red: 0.12, green: 0.42, blue: 0.78)
        case .green: Color(red: 0.12, green: 0.55, blue: 0.25)
        case .pink: Color(red: 0.76, green: 0.20, blue: 0.42)
        case .purple: Color(red: 0.48, green: 0.28, blue: 0.78)
        }
    }
}

extension Color {
    static var clipCanvasPageBackground: Color {
        #if canImport(UIKit)
        Color(.systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.background)
        #endif
    }

    static var clipCanvasCardBackground: Color {
        #if canImport(UIKit)
        Color(.systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.background)
        #endif
    }

    static var clipCanvasSecondaryBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color.secondary.opacity(0.12)
        #endif
    }

    static var clipCanvasInputBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemFill)
        #elseif canImport(AppKit)
        Color(nsColor: .textBackgroundColor)
        #else
        Color.secondary.opacity(0.10)
        #endif
    }
}
