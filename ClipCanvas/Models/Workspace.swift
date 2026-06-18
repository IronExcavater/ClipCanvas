import CoreGraphics
import Foundation
import SwiftData

@Model
final class Workspace: SoftDeletable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var isActive: Bool = false
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil

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
        let i = Double(canvasObjects.count)
        return CGPoint(
            x: 200 + i.truncatingRemainder(dividingBy: 6) * 30,
            y: 180 + i.truncatingRemainder(dividingBy: 8) * 24
        )
    }

    func nextPosition(around anchor: CGPoint) -> CGPoint {
        let i = Double(canvasObjects.count)
        let column = i.truncatingRemainder(dividingBy: 4)
        let row = floor(i.truncatingRemainder(dividingBy: 12) / 4)
        return CGPoint(
            x: anchor.x - 110 + column * 28,
            y: anchor.y - 75 + row * 24
        )
    }

    @discardableResult
    func createNote(centeredAt center: CGPoint, size: CGSize, text: String = "") -> CanvasObject {
        let object = CanvasObject(
            kind: .stickyNote,
            workspace: self,
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height,
            text: text
        )
        object.zIndex = Double(canvasObjects.count)
        canvasObjects.append(object)
        updatedAt = Date()
        return object
    }

    @discardableResult
    func createText(centeredAt center: CGPoint, text: String = "") -> CanvasObject {
        let size = CGSize(width: 280, height: 96)
        let object = CanvasObject(
            kind: .text,
            workspace: self,
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height,
            text: text,
            style: .freeText
        )
        object.zIndex = Double(canvasObjects.count)
        canvasObjects.append(object)
        updatedAt = Date()
        return object
    }

    @discardableResult
    func place(clip: Clip, at position: CGPoint? = nil) -> CanvasObject {
        let pos = position ?? nextPosition()
        let isImage = clip.type == .image
        let size = isImage
            ? CGSize(width: 260, height: 190)
            : CanvasPlacementSizing.defaultSize
        let object = CanvasObject(
            kind: isImage ? .image : .clipNote,
            workspace: self,
            clip: clip,
            x: pos.x,
            y: pos.y,
            width: size.width,
            height: size.height
        )
        object.zIndex = Double(canvasObjects.count)
        canvasObjects.append(object)
        updatedAt = Date()
        return object
    }
}
