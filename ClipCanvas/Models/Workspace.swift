import CoreGraphics
import Foundation
import SwiftData

@Model
final class Workspace: SoftDeletable {
    var id: UUID = UUID()
    var name: String
    var isActive: Bool = false
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \CanvasPlacement.workspace)
    var placements: [CanvasPlacement] = []

    @Relationship(deleteRule: .cascade, inverse: \CanvasObject.workspace)
    var canvasObjects: [CanvasObject] = []

    @Relationship(deleteRule: .cascade, inverse: \AIChat.workspace)
    var chats: [AIChat] = []

    init(name: String, sortIndex: Int = 0, isActive: Bool = false) {
        self.name = name
        self.sortIndex = sortIndex
        self.isActive = isActive
    }

    func softDelete() {
        deletedAt = Date()
        isActive = false
    }

    // Staggers new cards so they don't all land on top of each other.
    func nextPosition() -> CGPoint {
        let i = Double(placements.count)
        return CGPoint(
            x: 200 + i.truncatingRemainder(dividingBy: 6) * 30,
            y: 180 + i.truncatingRemainder(dividingBy: 8) * 24
        )
    }

    func nextPosition(around anchor: CGPoint) -> CGPoint {
        let i = Double(placements.count)
        let column = i.truncatingRemainder(dividingBy: 4)
        let row = floor(i.truncatingRemainder(dividingBy: 12) / 4)
        return CGPoint(
            x: anchor.x - 110 + column * 28,
            y: anchor.y - 75 + row * 24
        )
    }

    @discardableResult
    func place(clip: Clip, at position: CGPoint? = nil) -> CanvasPlacement {
        let pos = position ?? nextPosition()
        let p = CanvasPlacement(clip: clip, x: pos.x, y: pos.y)
        p.workspace = self
        placements.append(p)
        updatedAt = Date()
        return p
    }
}

@Model
final class CanvasPlacement {
    var id: UUID = UUID()
    var workspace: Workspace?
    var clip: Clip?           // nullify on clip delete — placement disappears naturally
    var x: Double
    var y: Double
    var width: Double = 220
    var height: Double = 150
    var createdAt: Date = Date()

    init(clip: Clip?, x: Double, y: Double) {
        self.clip = clip
        self.x = x
        self.y = y
    }
}

extension CanvasPlacement {
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
}
