import SwiftUI

struct FeedbackBanner: View {
    let message: String

    private var kind: FeedbackKind { FeedbackKind(message: message) }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(kind.tint)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            AppGlassSurface(shape: .capsule, stroke: Color.primary.opacity(0.06))
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 7)
    }
}

private enum FeedbackKind {
    case success
    case failure
    case question
    case info

    init(message: String) {
        let lower = message.lowercased()
        if lower.contains("error")
            || lower.contains("failed")
            || lower.contains("couldn't")
            || lower.contains("could not")
            || lower.contains("can't")
            || lower.contains("cannot")
            || lower.contains("not found") {
            self = .failure
        } else if lower.contains("?")
            || lower.contains("confirm")
            || lower.contains("confirmation")
            || lower.contains("approve") {
            self = .question
        } else if lower.contains("coming soon")
            || lower.contains("already")
            || lower.contains("select")
            || lower.contains("choose")
            || lower.contains("nothing")
            || lower.hasPrefix("no ") {
            self = .info
        } else {
            self = .success
        }
    }

    var systemImage: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.octagon.fill"
        case .question:
            return "questionmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success:
            return .green
        case .failure:
            return .red
        case .question:
            return .orange
        case .info:
            return Color.accentColor
        }
    }
}
