import Foundation
import SwiftData

struct CanvasUndoSnapshot {
    var objects: [CanvasObjectSnapshot]
    var drawingData: Data

    init(workspace: Workspace, drawingData: Data) {
        self.objects = workspace.canvasObjects
            .filter(\.isCanvasContent)
            .map(CanvasObjectSnapshot.init)
        self.drawingData = drawingData
    }

    func restore(in workspace: Workspace, context: ModelContext) {
        let snapshotObjectIDs = Set(objects.map(\.id))
        let currentObjects = workspace.canvasObjects.filter(\.isCanvasContent)

        for object in currentObjects where !snapshotObjectIDs.contains(object.id) {
            context.delete(object)
        }

        var restoredObjects: [CanvasObject] = []
        for snapshot in objects {
            let object = currentObjects.first(where: { $0.id == snapshot.id }) ?? snapshot.makeObject(workspace: workspace)
            if object.modelContext == nil {
                context.insert(object)
            }
            snapshot.apply(to: object, workspace: workspace, context: context)
            restoredObjects.append(object)
            if !workspace.canvasObjects.contains(where: { $0.id == object.id }) {
                workspace.canvasObjects.append(object)
            }
        }

        let restoredIDs = Set(restoredObjects.map(\.id))
        workspace.canvasObjects.removeAll { object in
            object.isCanvasContent && !restoredIDs.contains(object.id)
        }
        workspace.updatedAt = Date()
    }
}

struct CanvasObjectSnapshot {
    var id: UUID
    var kind: CanvasObjectKind
    var clip: CanvasClipSnapshot?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double
    var zIndex: Double
    var text: String
    var shapeKind: CanvasShapeKind?
    var style: CanvasObjectStyle
    var drawingData: Data?
    var connector: CanvasConnector?
    var groupID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(_ object: CanvasObject) {
        self.id = object.id
        self.kind = object.kind
        self.clip = object.clip.map(CanvasClipSnapshot.init)
        self.x = object.x
        self.y = object.y
        self.width = object.width
        self.height = object.height
        self.rotation = object.rotation
        self.zIndex = object.zIndex
        self.text = object.text
        self.shapeKind = object.shapeKind
        self.style = object.style
        self.drawingData = object.drawingData
        self.connector = object.connector
        self.groupID = object.groupID
        self.createdAt = object.createdAt
        self.updatedAt = object.updatedAt
        self.deletedAt = object.deletedAt
    }

    func makeObject(workspace: Workspace) -> CanvasObject {
        let object = CanvasObject(
            kind: kind,
            workspace: workspace,
            x: x,
            y: y,
            width: width,
            height: height,
            text: text,
            shapeKind: shapeKind,
            style: style,
            connector: connector
        )
        object.id = id
        return object
    }

    func apply(to object: CanvasObject, workspace: Workspace, context: ModelContext) {
        object.kind = kind
        object.workspace = workspace
        object.clip = clip?.resolvedClip(in: context)
        object.x = x
        object.y = y
        object.width = width
        object.height = height
        object.rotation = rotation
        object.zIndex = zIndex
        object.text = text
        object.shapeKind = shapeKind
        object.style = style
        object.drawingData = drawingData
        object.connector = connector
        object.groupID = groupID
        object.createdAt = createdAt
        object.updatedAt = updatedAt
        object.deletedAt = deletedAt
    }
}

struct CanvasClipSnapshot {
    var id: UUID
    var content: String
    var imageData: Data?
    var imageUTI: String?
    var imageName: String?
    var type: ClipType
    var isTypeManuallySet: Bool
    var origin: ClipOrigin
    var sensitivity: Sensitivity
    var sensitivityReason: SensitivityReason?
    var expiresAt: Date?
    var color: CardColor
    var isPinned: Bool
    var isCanvasOnly: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var tags: [ClipTag]

    init(_ clip: Clip) {
        self.id = clip.id
        self.content = clip.content
        self.imageData = clip.imageData
        self.imageUTI = clip.imageUTI
        self.imageName = clip.imageName
        self.type = clip.type
        self.isTypeManuallySet = clip.isTypeManuallySet
        self.origin = clip.origin
        self.sensitivity = clip.sensitivity
        self.sensitivityReason = clip.sensitivityReason
        self.expiresAt = clip.expiresAt
        self.color = clip.color
        self.isPinned = clip.isPinned
        self.isCanvasOnly = clip.isCanvasOnly
        self.createdAt = clip.createdAt
        self.updatedAt = clip.updatedAt
        self.deletedAt = clip.deletedAt
        self.tags = clip.tags
    }

    func resolvedClip(in context: ModelContext) -> Clip {
        let clip = existingClip(in: context) ?? makeClip()
        if clip.modelContext == nil {
            context.insert(clip)
        }
        apply(to: clip)
        return clip
    }

    private func makeClip() -> Clip {
        let clip = Clip(
            content: content,
            imageData: imageData,
            imageUTI: imageUTI,
            imageName: imageName,
            origin: origin,
            sensitivity: sensitivity,
            sensitivityReason: sensitivityReason,
            color: color
        )
        clip.id = id
        return clip
    }

    private func apply(to clip: Clip) {
        clip.content = content
        clip.imageData = imageData
        clip.imageUTI = imageUTI
        clip.imageName = imageName
        clip.type = type
        clip.isTypeManuallySet = isTypeManuallySet
        clip.origin = origin
        clip.sensitivity = sensitivity
        clip.sensitivityReason = sensitivityReason
        clip.expiresAt = expiresAt
        clip.color = color
        clip.isPinned = isPinned
        clip.isCanvasOnly = isCanvasOnly
        clip.createdAt = createdAt
        clip.updatedAt = updatedAt
        clip.deletedAt = deletedAt
        clip.tags = tags
    }

    private func existingClip(in context: ModelContext) -> Clip? {
        let id = id
        let descriptor = FetchDescriptor<Clip>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
