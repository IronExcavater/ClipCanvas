import SwiftUI

struct FeedbackBanner: View {
    let message: String

    private var isError: Bool {
        let lower = message.lowercased()
        return lower.contains("error") || lower.contains("failed") || lower.contains("empty") || lower.contains("couldn't")
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isError ? Color.red : Color.accentColor)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            if #available(iOS 26, *) {
                Capsule()
                    .fill(Color.clear)
                    .glassEffect(.regular, in: .capsule)
            } else {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay { Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1) }
            }
        }
        .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
    }
}
