import Foundation

enum ClipClassificationService {
    nonisolated struct SensitivityClassification: Equatable {
        var sensitivity: Sensitivity
        var reason: SensitivityReason?
    }

    static func detectType(content: String, imageData: Data?) -> ClipType {
        if imageData != nil { return .image }
        if looksLikeURL(content) { return .url }
        if looksLikeCode(content) { return .code }
        return .text
    }

    static func detectSensitivity(_ text: String) -> Sensitivity {
        classifySensitivity(text).sensitivity
    }

    static func classifySensitivity(_ text: String) -> SensitivityClassification {
        let range = NSRange(text.startIndex..., in: text)
        if looksLikePassword(text) {
            return SensitivityClassification(sensitivity: .privateContent, reason: .passwordLike)
        }
        if secretRegex.firstMatch(in: text, range: range) != nil {
            return SensitivityClassification(sensitivity: .privateContent, reason: .secretKeyword)
        }
        for (reason, pattern) in piiPatterns where pattern.firstMatch(in: text, range: range) != nil {
            return SensitivityClassification(sensitivity: .sensitive, reason: reason)
        }
        return SensitivityClassification(sensitivity: .normal, reason: nil)
    }

    private static let urlPrefixRegex = try! NSRegularExpression(
        pattern: #"^(?:https?://|www\.)\S"#,
        options: .caseInsensitive
    )

    private static let codeKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:func|class|struct|enum|import|def|async|function|const|interface|extends|implements|public|private|protected|static|return|override|void|#include|#import|SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|ALTER)\b"#
    )

    private static let codeOperatorRegex = try! NSRegularExpression(
        pattern: #"(?:->|=>|::|===|!==|\?\?|&&|\|\||\+=|-=|\*=|/=)"#
    )

    private static let secretRegex = try! NSRegularExpression(
        pattern: #"\b(?:password|passwd|secret|api[-_]?key|api[-_]?token|access[-_]?key|auth[-_]?key|bearer|private[-_]?key|client[-_]?secret)\b"#,
        options: .caseInsensitive
    )

    private static let piiPatterns: [(SensitivityReason, NSRegularExpression)] = [
        (.ssn, try! NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#)),
        (.creditCard, try! NSRegularExpression(pattern: #"\b(?:\d[ -]?){13,19}\b"#)),
        (.email, try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#)),
    ]

    private static func looksLikeURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n"), (4...2048).contains(trimmed.count) else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard urlPrefixRegex.firstMatch(in: trimmed, range: range) != nil else { return false }
        let candidate = trimmed.lowercased().hasPrefix("www.") ? "https://\(trimmed)" : trimmed
        guard let url = URL(string: candidate), let host = url.host else { return false }
        return host.contains(".")
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return false }
        let range = NSRange(text.startIndex..., in: text)
        let keywords = codeKeywordRegex.numberOfMatches(in: text, range: range)
        let operators = codeOperatorRegex.numberOfMatches(in: text, range: range)
        let braces = text.filter { "{}[]".contains($0) }.count
        let hasIndent = lines.dropFirst().contains { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        let semicolons = text.filter { $0 == ";" }.count

        var score = 0
        score += min(keywords, 3)
        score += min(operators, 2)
        score += braces >= 4 ? 2 : braces >= 2 ? 1 : 0
        if hasIndent { score += 1 }
        if semicolons >= 2 { score += 1 }
        return score >= 3
    }

    private static func looksLikePassword(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace), (10...128).contains(trimmed.count) else {
            return false
        }

        let hasUpper = trimmed.contains(where: \.isUppercase)
        let hasLower = trimmed.contains(where: \.isLowercase)
        let hasDigit = trimmed.contains(where: \.isNumber)
        let hasSymbol = trimmed.contains { !$0.isLetter && !$0.isNumber }
        return [hasUpper, hasLower, hasDigit, hasSymbol].filter { $0 }.count >= 3
    }
}
