import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PasteboardService {
    static func readString() -> String? {
        #if canImport(UIKit)
        UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        #elseif canImport(AppKit)
        NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        #else
        nil
        #endif
    }

    static func writeString(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
