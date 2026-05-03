import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct PasteboardService {
    static func readString() -> String? {
        #if canImport(UIKit)
        UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        #else
        nil
        #endif
    }

    static func writeString(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
