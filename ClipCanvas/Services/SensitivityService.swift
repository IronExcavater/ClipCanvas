import Foundation

enum SensitivityService {

    private static let privateKeywords = [
        "password", "passwd", "secret", "api_key", "apikey",
        "token", "private_key", "access_key", "auth_key", "bearer",
    ]

    // Pre-compiled regexes: SSN, credit card, email
    private static let piiPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#),
        try! NSRegularExpression(pattern: #"\b(?:\d[ -]?){13,19}\b"#),
        try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#),
    ]

    static func detect(_ text: String) -> Sensitivity {
        let lower = text.lowercased()
        // Private keywords checked first — higher severity wins
        if privateKeywords.contains(where: { lower.contains($0) }) {
            return .privateContent
        }
        let range = NSRange(text.startIndex..., in: text)
        if piiPatterns.contains(where: { $0.firstMatch(in: text, range: range) != nil }) {
            return .sensitive
        }
        return .normal
    }
}
