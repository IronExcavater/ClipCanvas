import SwiftUI

// Transient feedback pill — appears at top of screen for 1.7s then fades out.
// Usage: overlay(alignment: .top) { FeedbackBanner(message: feedback) }
struct FeedbackBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 4, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
