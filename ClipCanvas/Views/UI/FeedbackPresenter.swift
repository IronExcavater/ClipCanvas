import Foundation
import Observation
import SwiftUI

struct FeedbackItem: Identifiable, Equatable {
    let id: UUID
    let message: String
    var kind: FeedbackKind?
}

@MainActor
@Observable
final class FeedbackPresenter {
    private(set) var item: FeedbackItem?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    @discardableResult
    func show(
        _ message: String,
        kind: FeedbackKind? = nil,
        duration: Duration = .seconds(1.7),
        autoDismiss: Bool = true
    ) -> FeedbackItem {
        hideTask?.cancel()
        let next = FeedbackItem(id: UUID(), message: message, kind: kind)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            item = next
        }

        if autoDismiss {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: duration)
                self?.dismiss(id: next.id)
            }
        }

        return next
    }

    func dismiss(id: UUID? = nil) {
        guard id == nil || item?.id == id else { return }
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            item = nil
        }
    }
}

struct FeedbackOverlayModifier: ViewModifier {
    let presenter: FeedbackPresenter
    var topPadding: CGFloat = 70

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let item = presenter.item {
                    FeedbackBanner(message: item.message, kind: item.kind)
                        .id(item.id)
                        .padding(.top, topPadding)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.94)),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.96))
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.86), value: presenter.item?.id)
    }
}

extension View {
    func appFeedbackOverlay(
        _ presenter: FeedbackPresenter,
        topPadding: CGFloat = 70
    ) -> some View {
        modifier(FeedbackOverlayModifier(presenter: presenter, topPadding: topPadding))
    }
}
