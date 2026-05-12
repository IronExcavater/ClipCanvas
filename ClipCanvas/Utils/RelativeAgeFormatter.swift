import Foundation

enum RelativeAgeFormatter {
    static func shortString(since date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        guard seconds >= 1 else { return "" }

        let units: [(seconds: Int, suffix: String)] = [
            (365 * 24 * 60 * 60, "y"),
            (30 * 24 * 60 * 60, "mo"),
            (24 * 60 * 60, "d"),
            (60 * 60, "h"),
            (60, "m"),
            (1, "s"),
        ]

        var remaining = seconds
        var parts: [String] = []
        for unit in units {
            let value = remaining / unit.seconds
            guard value > 0 else { continue }
            parts.append("\(value)\(unit.suffix)")
            remaining %= unit.seconds
            if parts.count == 2 { break }
        }
        return parts.joined(separator: " ")
    }
}

