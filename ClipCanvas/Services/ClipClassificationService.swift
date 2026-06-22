import Foundation

enum ClipClassificationService {
    nonisolated struct SensitiveSpan: Equatable {
        var range: NSRange
        var sensitivity: Sensitivity
        var reason: SensitivityReason
    }

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
        let spans = sensitiveSpans(in: text)
        if let privateSpan = spans.first(where: { $0.sensitivity == .privateContent }) {
            return SensitivityClassification(sensitivity: .privateContent, reason: privateSpan.reason)
        }
        if let sensitiveSpan = spans.first {
            return SensitivityClassification(sensitivity: .sensitive, reason: sensitiveSpan.reason)
        }
        return SensitivityClassification(sensitivity: .normal, reason: nil)
    }

    static func markSensitiveMarkdown(in text: String) -> String {
        let spans = sensitiveSpans(in: text)
            .filter { $0.sensitivity == .privateContent }
            .filter { $0.reason != .userMarkedPrivate }
            .filter {
                guard let range = Range($0.range, in: text) else { return false }
                return !text[range].contains("||")
            }
            .sorted { $0.range.location > $1.range.location }

        guard !spans.isEmpty else { return text }

        var marked = text
        for span in spans {
            guard let range = Range(span.range, in: marked) else { continue }
            marked.replaceSubrange(range, with: "||\(marked[range])||")
        }
        return marked
    }

    static func sensitiveSpans(in text: String) -> [SensitiveSpan] {
        let range = NSRange(text.startIndex..., in: text)
        var spans: [SensitiveSpan] = explicitSensitiveSpans(in: text)

        for match in secretValueRegex.matches(in: text, range: range) {
            let valueRange = match.range(at: 1)
            if valueRange.location != NSNotFound {
                spans.append(SensitiveSpan(range: valueRange, sensitivity: .privateContent, reason: .secretKeyword))
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikePassword(text), let range = text.range(of: trimmed) {
            spans.append(SensitiveSpan(range: NSRange(range, in: text), sensitivity: .privateContent, reason: .passwordLike))
        }

        for (reason, pattern) in piiPatterns {
            for match in pattern.matches(in: text, range: range) {
                spans.append(SensitiveSpan(range: match.range, sensitivity: .sensitive, reason: reason))
            }
        }

        return nonOverlapping(spans)
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

    private static let explicitSensitiveRegex = try! NSRegularExpression(
        pattern: #"\|\|(.+?)\|\|"#
    )

    private static let secretValueRegex = try! NSRegularExpression(
        pattern: #"\b(?:password|passwd|secret|api[-_]?key|api[-_]?token|access[-_]?key|auth[-_]?key|bearer(?:\s+token)?|private[-_]?key|client[-_]?secret)\b(?:\s+for\s+\S+\s+is\s+|\s*[:=]\s*|\s+)([^\s,;]+)"#,
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

    private static func explicitSensitiveSpans(in text: String) -> [SensitiveSpan] {
        let range = NSRange(text.startIndex..., in: text)
        return explicitSensitiveRegex.matches(in: text, range: range).compactMap { match in
            let valueRange = match.range(at: 1)
            guard valueRange.location != NSNotFound else { return nil }
            return SensitiveSpan(range: valueRange, sensitivity: .privateContent, reason: .userMarkedPrivate)
        }
    }

    private static func nonOverlapping(_ spans: [SensitiveSpan]) -> [SensitiveSpan] {
        spans
            .sorted {
                if $0.range.location == $1.range.location {
                    return $0.range.length > $1.range.length
                }
                return $0.range.location < $1.range.location
            }
            .reduce(into: [SensitiveSpan]()) { output, span in
                guard !output.contains(where: { NSIntersectionRange($0.range, span.range).length > 0 }) else { return }
                output.append(span)
            }
    }
}
