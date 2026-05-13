import CoreGraphics
import Foundation
import SwiftData

nonisolated enum CanvasObjectKind: String, Codable, CaseIterable {
    case stickyNote
    case clipNote
    case image
    case drawing
    case shape
    case connector
    case group
}

nonisolated enum CanvasShapeKind: String, Codable, CaseIterable {
    case rectangle
    case roundedRectangle
    case circle
    case diamond
    case capsule
}

nonisolated enum CanvasAnchor: String, Codable, CaseIterable {
    case center
    case top
    case trailing
    case bottom
    case leading
    case free
}

nonisolated struct CGPointCodable: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

nonisolated struct CanvasObjectStyle: Codable, Equatable {
    var fillHex: String
    var strokeHex: String?
    var textHex: String?
    var lineWidth: Double
    var fontSize: Double

    static let `default` = CanvasObjectStyle(
        fillHex: "#FFF3B0",
        strokeHex: nil,
        textHex: "#1C1C1E",
        lineWidth: 0,
        fontSize: 16
    )
}

nonisolated struct CanvasConnectorEndpoint: Codable, Equatable {
    var objectID: UUID?
    var point: CGPointCodable
    var anchor: CanvasAnchor
}

nonisolated struct CanvasConnector: Codable, Equatable {
    var start: CanvasConnectorEndpoint
    var end: CanvasConnectorEndpoint
}

@Model
final class CanvasObject {
    var id: UUID = UUID()
    var kindRaw: String
    var workspace: Workspace?
    var clip: Clip?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double = 0
    var zIndex: Double = 0
    var text: String = ""
    var shapeKindRaw: String?
    var styleData: Data?
    var drawingData: Data?
    var connectorData: Data?
    var groupID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date?

    init(
        kind: CanvasObjectKind,
        workspace: Workspace? = nil,
        clip: Clip? = nil,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        text: String = "",
        shapeKind: CanvasShapeKind? = nil,
        style: CanvasObjectStyle = .default,
        connector: CanvasConnector? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.workspace = workspace
        self.clip = clip
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
        self.shapeKindRaw = shapeKind?.rawValue
        self.styleData = Self.encode(style)
        self.connectorData = Self.encode(connector)
    }
}

extension CanvasObject: SoftDeletable {
    func softDelete() {
        deletedAt = Date()
    }
}

extension CanvasObject {
    var kind: CanvasObjectKind {
        get { CanvasObjectKind(rawValue: kindRaw) ?? .stickyNote }
        set { kindRaw = newValue.rawValue }
    }

    var shapeKind: CanvasShapeKind? {
        get {
            guard let shapeKindRaw else { return nil }
            return CanvasShapeKind(rawValue: shapeKindRaw)
        }
        set {
            shapeKindRaw = newValue?.rawValue
        }
    }

    var style: CanvasObjectStyle {
        get { Self.decode(CanvasObjectStyle.self, from: styleData) ?? .default }
        set { styleData = Self.encode(newValue) }
    }

    var connector: CanvasConnector? {
        get { Self.decode(CanvasConnector.self, from: connectorData) }
        set { connectorData = Self.encode(newValue) }
    }

    var frame: CGRect {
        get {
            CGRect(x: x, y: y, width: width, height: height)
        }
        set {
            x = Double(newValue.origin.x)
            y = Double(newValue.origin.y)
            width = Double(newValue.width)
            height = Double(newValue.height)
        }
    }

    var displayText: String {
        if kind == .clipNote {
            return clip?.content ?? text
        }
        return text
    }

    var isVisible: Bool {
        guard deletedAt == nil else { return false }
        guard kind == .clipNote else { return true }
        return clip?.deletedAt == nil
    }

    func markUpdated(at date: Date = Date()) {
        updatedAt = date
    }
}

private extension CanvasObject {
    static func encode<T: Encodable>(_ value: T?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
