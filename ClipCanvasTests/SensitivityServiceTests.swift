import Testing
@testable import ClipCanvas

@Suite struct SensitivityServiceTests {

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
}
