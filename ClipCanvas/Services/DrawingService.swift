import Foundation
import PencilKit

// Stores PencilKit drawings as files — one per workspace UUID.
// Using files instead of SwiftData avoids re-rendering all canvas cards on every pen stroke.
enum DrawingService {
    private static var drawingsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("CanvasDrawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func url(for id: UUID) -> URL {
        drawingsDirectory.appendingPathComponent("\(id.uuidString).pkdrawing")
    }

    static func load(for id: UUID) -> PKDrawing {
        let url = url(for: id)
        guard let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }

    static func save(_ drawing: PKDrawing, for id: UUID) {
        if drawing.bounds.isEmpty {
            delete(for: id)
        } else {
            try? drawing.dataRepresentation().write(to: url(for: id), options: .atomic)
        }
    }

    static func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    static func hasDrawing(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: drawingsDirectory)
        try? FileManager.default.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
    }
}
