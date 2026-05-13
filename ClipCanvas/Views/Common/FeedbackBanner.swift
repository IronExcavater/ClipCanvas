import SwiftUI

struct FeedbackBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if #available(iOS 26, *) {
                    Capsule()
                        .fill(Color.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                } else {
                    Capsule().fill(.regularMaterial)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
