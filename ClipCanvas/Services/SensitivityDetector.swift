import Foundation

struct SensitivityDetector {
    static func detect(for text: String) -> Sensitivity {
        let lowercased = text.lowercased()

        // Keyword check: these terms strongly suggest the snippet contains a secret.
        // Matched as substrings so "password123" and "API_KEY" are both caught.
        let privateTerms = ["password", "passcode", "secret", "api_key", "apikey", "token"]
        if privateTerms.contains(where: { lowercased.contains($0) }) {
            return .privateContent
        }

        // Regex checks catch common personally-identifiable data shapes.
        // This is a UX safety net to protect against accidental exposure, not a security boundary.
        let patterns = [
            #"(?i)\b\d{3}-\d{2}-\d{4}\b"#,                             // Social Security Number
            #"(?i)\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b"#,          // Credit/debit card number
            #"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#          // Email address
        ]

        for pattern in patterns {
            // range(of:options:) returns nil if no match — .regularExpression treats the string as a regex.
            if text.range(of: pattern, options: .regularExpression) != nil {
                return .sensitive
            }
        }

        return .normal
    }
}
