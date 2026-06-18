import SwiftUI

struct AppConfirmationOverlay: View {
    let title: String
    var message: String?
    var destructiveTitle = "Delete"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(AppConfirmationButtonStyle())

                    Button(role: .destructive, action: onConfirm) {
                        Text(destructiveTitle)
                    }
                    .buttonStyle(AppConfirmationButtonStyle(tint: .red))
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .glassPanel(cornerRadius: 22, shadow: true, interactive: true)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

private struct AppConfirmationButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(tint ?? .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background {
                AppGlassSurface(
                    shape: .rect(cornerRadius: 14),
                    tint: tint?.opacity(0.16),
                    fallback: .color((tint ?? Color.primary).opacity(0.08)),
                    interactive: true
                )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
