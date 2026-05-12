import Testing
@testable import ClipCanvas

@Suite struct SensitivityServiceTests {

    @Test func normalText() {
        #expect(SensitivityService.detect("Buy oat milk") == .normal)
    }

    @Test func emailAddress() {
        #expect(SensitivityService.detect("contact me at foo@bar.com") == .sensitive)
    }

    @Test func socialSecurityNumber() {
        #expect(SensitivityService.detect("SSN: 123-45-6789") == .sensitive)
    }

    @Test func creditCard() {
        #expect(SensitivityService.detect("card 4111 1111 1111 1111 exp 12/28") == .sensitive)
    }

    @Test func passwordKeyword() {
        #expect(SensitivityService.detect("password: hunter2") == .privateContent)
    }

    @Test func apiKeyKeyword() {
        #expect(SensitivityService.detect("api_key=abc123secretxyz") == .privateContent)
    }

    @Test func apiTokenKeyword() {
        #expect(SensitivityService.detect("api_token=abc123") == .privateContent)
    }

    @Test func bearerKeyword() {
        #expect(SensitivityService.detect("bearer token: eyJhbGciOiJIUzI") == .privateContent)
    }

    @Test func privateKeywordWinsOverPII() {
        #expect(SensitivityService.detect("password for foo@bar.com is hunter2") == .privateContent)
    }

    @Test func wordBoundaryPreventsPartialMatch() {
        // "tokenize" should NOT match the "token" rule (no standalone "token" word)
        #expect(SensitivityService.detect("I need to tokenize this text") == .normal)
    }

    @Test func clientSecretDetected() {
        #expect(SensitivityService.detect("client_secret=abc123xyz") == .privateContent)
    }
}
