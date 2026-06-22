import Testing
@testable import ClipCanvas

@Suite struct AIChatCommandRouterParsingTests {
    @Test func createNoteAnsweringQuestionUsesModelInsteadOfLiteralNote() {
        let command = AIChatCommandRouter.Command(message: "Create a note answering what SwiftData is")

        #expect(command.isAskModel)
    }

    @Test func createNoteWithExplicitTextStillCreatesLocalNote() {
        let command = AIChatCommandRouter.Command(message: "Create a note that says Ship the build")

        #expect(command.createdNoteText == "Ship the build")
    }
}

private extension AIChatCommandRouter.Command {
    var isAskModel: Bool {
        if case .askModel = self { return true }
        return false
    }

    var createdNoteText: String? {
        if case .createNote(let text) = self { return text }
        return nil
    }
}
