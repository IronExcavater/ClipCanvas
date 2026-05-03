import SwiftUI

extension CardColor {
    var background: Color {
        switch self {
        case .default: Color(.systemBackground)
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
}
