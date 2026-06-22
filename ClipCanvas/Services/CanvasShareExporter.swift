import Foundation

@MainActor enum CanvasShareExporter {
    private static var temporaryImageURLs: [String: URL] = [:]

    static func workspaceText(_ workspace: Workspace) -> String {
        let objects = orderedContentObjects(workspace.canvasObjects)
        let body = objects.map(cardText).filter { !$0.isEmpty }.joined(separator: "\n\n")
        return body.isEmpty ? "# \(workspace.name)" : "# \(workspace.name)\n\n\(body)"
    }

    static func cardsText(_ objects: [CanvasObject], title: String = "ClipCanvas Cards") -> String {
        let body = orderedContentObjects(objects).map(cardText).filter { !$0.isEmpty }.joined(separator: "\n\n")
        return body.isEmpty ? title : "\(title)\n\n\(body)"
    }

    static func imageURLs(for objects: [CanvasObject]) -> [URL] {
        orderedContentObjects(objects).compactMap { object in
            guard let clip = object.clip,
                  clip.type == .image,
                  let data = clip.imageData else { return nil }
            let ext = fileExtension(for: clip.imageUTI)
            let cacheKey = "\(object.id.uuidString)-\(clip.imageUTI ?? "public.png")-\(data.count)-\(data.hashValue)"
            if let cached = temporaryImageURLs[cacheKey],
               FileManager.default.fileExists(atPath: cached.path) {
                return cached
            }
            let keySuffix = String(abs(data.hashValue), radix: 16)
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ClipCanvasShares", isDirectory: true)
                .appendingPathComponent("Images", isDirectory: true)
            let url = directory
                .appendingPathComponent("ClipCanvas-\(object.id.uuidString)-\(keySuffix)")
                .appendingPathExtension(ext)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
                temporaryImageURLs[cacheKey] = url
                return url
            } catch {
                return nil
            }
        }
    }

    private static func orderedContentObjects(_ objects: [CanvasObject]) -> [CanvasObject] {
        objects
            .filter(\.isCanvasContent)
            .sorted { lhs, rhs in
                if lhs.zIndex == rhs.zIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.zIndex < rhs.zIndex
            }
    }

    private static func cardText(_ object: CanvasObject) -> String {
        if object.kind == .image || object.clip?.type == .image {
            let label = object.clip?.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return label?.isEmpty == false ? "![\(label!)]" : "![Image]"
        }
        let text = object.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        return text
    }

    private static func fileExtension(for uti: String?) -> String {
        switch uti {
        case "public.jpeg", "public.jpg": return "jpg"
        case "public.tiff": return "tiff"
        case "public.heic": return "heic"
        default: return "png"
        }
    }
}
