import Testing
@testable import ClipCanvas

@Suite struct ClipClassificationServiceTests {

    @Test func normalText() {
        #expect(ClipClassificationService.detectSensitivity("Buy oat milk") == .normal)
    }

    @Test func emailAddress() {
        #expect(ClipClassificationService.detectSensitivity("contact me at foo@bar.com") == .sensitive)
    }

    @Test func socialSecurityNumber() {
        #expect(ClipClassificationService.detectSensitivity("SSN: 123-45-6789") == .sensitive)
    }

    @Test func creditCard() {
        #expect(ClipClassificationService.detectSensitivity("card 4111 1111 1111 1111 exp 12/28") == .sensitive)
    }

    @Test func passwordKeyword() {
        #expect(ClipClassificationService.detectSensitivity("password: hunter2") == .privateContent)
    }

    @Test func apiKeyKeyword() {
        #expect(ClipClassificationService.detectSensitivity("api_key=abc123secretxyz") == .privateContent)
    }

    @Test func apiTokenKeyword() {
        #expect(ClipClassificationService.detectSensitivity("api_token=abc123") == .privateContent)
    }

    @Test func bearerKeyword() {
        #expect(ClipClassificationService.detectSensitivity("bearer token: eyJhbGciOiJIUzI") == .privateContent)
    }

    @Test func privateKeywordWinsOverPII() {
        #expect(ClipClassificationService.detectSensitivity("password for foo@bar.com is hunter2") == .privateContent)
    }

    @Test func wordBoundaryPreventsPartialMatch() {
        // "tokenize" should NOT match the "token" rule (no standalone "token" word)
        #expect(ClipClassificationService.detectSensitivity("I need to tokenize this text") == .normal)
    }

    @Test func clientSecretDetected() {
        #expect(ClipClassificationService.detectSensitivity("client_secret=abc123xyz") == .privateContent)
    }

    @Test func classificationIncludesReason() {
        let classification = ClipClassificationService.classifySensitivity("N0tArealP@ssword1")

        #expect(classification.sensitivity == .privateContent)
        #expect(classification.reason == .passwordLike)
    }

    @Test func sensitiveMarkdownWrapsOnlyPasswordValue() {
        let marked = ClipClassificationService.markSensitiveMarkdown(in: "password: hunter2 for staging")

        #expect(marked == "password: ||hunter2|| for staging")
    }

    @Test func sensitiveMarkdownWrapsOnlyApiKeyValue() {
        let marked = ClipClassificationService.markSensitiveMarkdown(in: "api_key=abc123secretxyz owner: dev")

        #expect(marked == "api_key=||abc123secretxyz|| owner: dev")
    }

    @Test func explicitSensitiveMarkdownClassifiesAsPrivateContent() {
        let classification = ClipClassificationService.classifySensitivity("Deploy with ||manual-secret||")

        #expect(classification.sensitivity == .privateContent)
        #expect(classification.reason == .userMarkedPrivate)
    }

    @Test func existingSensitiveMarkdownIsNotWrappedAgain() {
        let marked = ClipClassificationService.markSensitiveMarkdown(in: "Deploy with ||manual-secret||")

        #expect(marked == "Deploy with ||manual-secret||")
    }

    @Test func labelledExistingSensitiveMarkdownIsNotWrappedAgain() {
        let marked = ClipClassificationService.markSensitiveMarkdown(in: "password: ||hunter2||")

        #expect(marked == "password: ||hunter2||")
    }
}
