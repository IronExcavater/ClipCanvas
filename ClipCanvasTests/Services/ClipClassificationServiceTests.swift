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

    @Test func bareOpenAIProjectKeyDetected() {
        let key = openAIProjectKeyFixture

        let classification = ClipClassificationService.classifySensitivity(key)

        #expect(classification.sensitivity == .privateContent)
        #expect(classification.reason == .secretKeyword)
    }

    @Test func bareOpenAIProjectKeyIsMasked() {
        let key = openAIProjectKeyFixture

        let marked = ClipClassificationService.markSensitiveMarkdown(in: "OpenAI key \(key)")

        #expect(marked == "OpenAI key ||\(key)||")
    }

    @Test func commonProviderKeysDetectedWithoutLabels() {
        #expect(ClipClassificationService.detectSensitivity("ghp_abcdefghijklmnopqrstuvwxyzABCDE1234") == .privateContent)
        #expect(ClipClassificationService.detectSensitivity("AKIAIOSFODNN7EXAMPLE") == .privateContent)
        #expect(ClipClassificationService.detectSensitivity("AIzaSyA123456789012345678901234567890123") == .privateContent)
    }

    @Test func urlDoesNotBecomePasswordLike() {
        let url = "https://example.com/reset/Aa1234567890-token_value"

        let classification = ClipClassificationService.classifySensitivity(url)

        #expect(ClipClassificationService.detectType(content: url, imageData: nil) == .url)
        #expect(classification.sensitivity == .normal)
        #expect(classification.reason == nil)
    }

    @Test func markSensitiveAvailabilityRequiresDetectableSecret() {
        #expect(!ClipClassificationService.canMarkSensitiveMarkdown(in: "https://example.com/reset/Aa1234567890-token_value"))
        #expect(ClipClassificationService.canMarkSensitiveMarkdown(in: "api_key=abc123secretxyz"))
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

    @Test func detectsSingleLineJSONAsCode() {
        #expect(ClipClassificationService.detectType(content: #"{"name":"ClipCanvas","enabled":true}"#, imageData: nil) == .code)
    }

    @Test func detectsShellCommandAsCode() {
        #expect(ClipClassificationService.detectType(content: "xcodebuild -project ClipCanvas.xcodeproj -scheme ClipCanvas build", imageData: nil) == .code)
    }

    @Test func detectsSwiftSnippetAsCode() {
        #expect(ClipClassificationService.detectType(content: "let title: String = workspace.name", imageData: nil) == .code)
    }

    @Test func detectsMarkupAsCode() {
        #expect(ClipClassificationService.detectType(content: "<div class=\"clip\">Hello</div>", imageData: nil) == .code)
    }

    @Test func normalShortTextDoesNotBecomeCode() {
        #expect(ClipClassificationService.detectType(content: "Buy oat milk and bread", imageData: nil) == .text)
    }

    @Test func manualTypeOverridePersistsAcrossDetection() {
        let clip = Clip(content: "Buy oat milk", origin: .typed)

        clip.setManualType(.code)
        clip.content = "Still just a sentence"
        clip.updateDetectedType()

        #expect(clip.type == .code)
        #expect(clip.isTypeManuallySet)
    }

    @Test func textClipCannotBeManuallyChangedToImage() {
        let clip = Clip(content: "Buy oat milk", origin: .typed)

        clip.setManualType(.image)

        #expect(clip.type == .text)
    }

    private var openAIProjectKeyFixture: String {
        let prefix = ["sk", "proj", "test"].joined(separator: "-")
        let body = "6PF5dBfbIxR2qhjHfvMmLJS6REGoQJw9XJZdlQHThKomDusdjWBqfaG1dIFc26Euw6wDqNVfsTT3BlbkFJUyxZmofLaPfuNBz3K-jVjLP1yyQKnuh17a6vJ-mylZOKT_3jdxd634-D9fmcbPJ9_RI95Udu0A"
        return "\(prefix)_\(body)"
    }
}
