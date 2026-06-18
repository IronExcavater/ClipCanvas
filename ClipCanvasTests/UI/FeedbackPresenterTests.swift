import Testing
@testable import ClipCanvas

@MainActor
@Suite struct FeedbackPresenterTests {
    @Test func newestFeedbackSurvivesOlderDismissal() {
        let presenter = FeedbackPresenter()

        let first = presenter.show("Copied", autoDismiss: false)
        let second = presenter.show("Pasted", autoDismiss: false)

        presenter.dismiss(id: first.id)

        #expect(presenter.item == second)
    }

    @Test func dismissWithoutIdentifierClearsCurrentFeedback() {
        let presenter = FeedbackPresenter()

        presenter.show("Saved", autoDismiss: false)
        presenter.dismiss()

        #expect(presenter.item == nil)
    }
}
