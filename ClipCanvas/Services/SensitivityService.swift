import Foundation

enum SensitivityService {

    // Word-boundary regex catches "api_key" / "API-KEY" without matching "apikey_prefix_xyz"
    private static let secretRegex = try! NSRegularExpression(
        pattern: #"\b(?:password|passwd|secret|api[-_]?key|api[-_]?token|access[-_]?key|auth[-_]?key|bearer|private[-_]?key|client[-_]?secret)\b"#,
        options: .caseInsensitive
    )

    private static let piiPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#),              // SSN
        try! NSRegularExpression(pattern: #"\b(?:\d[ -]?){13,19}\b"#),             // credit card
        try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#), // email
    ]

    static func detect(_ text: String) -> Sensitivity {
        let range = NSRange(text.startIndex..., in: text)
        if secretRegex.firstMatch(in: text, range: range) != nil { return .privateContent }
        if piiPatterns.contains(where: { $0.firstMatch(in: text, range: range) != nil }) { return .sensitive }
        return .normal
    }
}
