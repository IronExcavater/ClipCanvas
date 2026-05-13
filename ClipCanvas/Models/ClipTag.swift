import Foundation
import SwiftData
import SwiftUI

@Model
final class ClipTag {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var isBuiltIn: Bool
    var sortIndex: Int

    init(name: String, colorHex: String, isBuiltIn: Bool, sortIndex: Int) {
        self.name = name
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.sortIndex = sortIndex
    }

    var color: Color {
        Color(hex: colorHex) ?? .secondary
    }
}

extension ClipTag {
    private static func builtInColorKey(for type: ClipType) -> String {
        "clipTypeColor.\(type.rawValue)"
    }

    static let builtInDefinitions: [(name: String, hex: String, sortIndex: Int)] = [
        ("Text", "#607D8B", 0),
        ("Link", "#4CAF50", 1),
        ("Code", "#9C27B0", 2),
        ("Image", "#FF9800", 3),
    ]

    static func builtInName(for type: ClipType) -> String {
        switch type {
        case .text: return "Text"
        case .url: return "Link"
        case .code: return "Code"
        case .image: return "Image"
        }
    }

    static func builtInHex(for type: ClipType) -> String {
        if let stored = UserDefaults.standard.string(forKey: builtInColorKey(for: type)) {
            return stored
        }
        switch type {
        case .text: return "#607D8B"
        case .url: return "#4CAF50"
        case .code: return "#9C27B0"
        case .image: return "#FF9800"
        }
    }

    static func builtInColor(for type: ClipType) -> Color {
        Color(hex: builtInHex(for: type)) ?? .secondary
    }

    static func setBuiltInColor(_ hex: String, for type: ClipType) {
        UserDefaults.standard.set(hex, forKey: builtInColorKey(for: type))
    }
}

extension Clip {
    var primaryDisplayTagName: String {
        if let first = tags.min(by: { $0.sortIndex < $1.sortIndex }) {
            return first.name
        }
        return ClipTag.builtInName(for: type)
    }

    var primaryDisplayColor: Color {
        if let first = tags.min(by: { $0.sortIndex < $1.sortIndex }) {
            return first.color
        }
        return ClipTag.builtInColor(for: type)
    }
}

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
