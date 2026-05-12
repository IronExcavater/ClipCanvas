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

    @Test func tokenKeyword() {
        #expect(SensitivityService.detect("bearer token: eyJhbGciOiJIUzI") == .privateContent)
    }

    @Test func privateKeywordWinsOverPII() {
        // if text has both a password keyword AND an email, privateContent wins
        #expect(SensitivityService.detect("password for foo@bar.com is hunter2") == .privateContent)
    }
}
