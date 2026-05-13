import Foundation

nonisolated protocol SoftDeletable: AnyObject {
    var deletedAt: Date? { get set }
    func softDelete()
}

extension SoftDeletable {
    var isDeleted: Bool { deletedAt != nil }
    func restore() { deletedAt = nil }
}
