import Foundation

struct SensitivityDetector {
    static func detect(for text: String) -> Sensitivity {
        let lowercased = text.lowercased()
        let privateTerms = ["password", "passcode", "secret", "api_key", "apikey", "token"]
        if privateTerms.contains(where: { lowercased.contains($0) }) {
            return .privateContent
        }

        let patterns = [
            #"(?i)\b\d{3}-\d{2}-\d{4}\b"#,
            #"(?i)\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b"#,
            #"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#
        ]

        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return .sensitive
            }
        }

        return .normal
    }
}
