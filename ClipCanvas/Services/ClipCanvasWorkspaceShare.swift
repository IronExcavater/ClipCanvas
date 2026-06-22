import Foundation
import SwiftData

struct ClipCanvasWorkspaceSharePayload: Codable {
    var format: String = "au.com.ironbyte.clipcanvas.workspace"
    var version: Int = 1
    var workspaceName: String
    var ownerName: String
    var sharedAt: Date
    var objects: [SharedCanvasObject]

    struct SharedCanvasObject: Codable {
        var kind: String
        var x: Double
        var y: Double
        var width: Double
        var height: Double
        var text: String
        var clipContent: String?
        var clipType: String?
        var imageDataBase64: String?
        var imageUTI: String?
        var fillHex: String
    }
}

@MainActor enum ClipCanvasWorkspaceShare {
    static let fileExtension = "clipcanvas"
    private static var temporaryShareURLs: [String: URL] = [:]

    static func temporaryShareURL(for workspace: Workspace, includeImages: Bool) -> URL? {
        let payload = payload(for: workspace, includeImages: includeImages)
        guard let data = try? JSONEncoder.clipCanvasShare.encode(payload) else { return nil }
        let cacheKey = "\(workspace.id.uuidString)-\(includeImages)-\(data.count)-\(data.hashValue)"
        if let cached = temporaryShareURLs[cacheKey],
           FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        let safeName = workspace.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        let keySuffix = String(abs(data.hashValue), radix: 16)
        let fileName = (safeName.isEmpty ? "ClipCanvas Workspace" : safeName) + "-\(keySuffix)." + fileExtension
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipCanvasShares", isDirectory: true)
        let url = directory.appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            temporaryShareURLs[cacheKey] = url
            return url
        } catch {
            return nil
        }
    }

    static func importWorkspace(from text: String, in context: ModelContext, existing: [Workspace]) -> Workspace? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let payload = try? JSONDecoder.clipCanvasShare.decode(ClipCanvasWorkspaceSharePayload.self, from: data),
              payload.format == "au.com.ironbyte.clipcanvas.workspace" else {
            return nil
        }

        let workspace = Workspace(
            name: payload.workspaceName.isEmpty ? "Shared Workspace" : payload.workspaceName,
            sortIndex: (existing.map(\.sortIndex).max() ?? -1) + 1,
            isActive: existing.isEmpty
        )
        workspace.isCollaborative = true
        workspace.ownerName = payload.ownerName
        workspace.sharedByName = payload.ownerName
        workspace.sharedAt = payload.sharedAt
        context.insert(workspace)

        for item in payload.objects {
            let clip = clip(from: item)
            if let clip { context.insert(clip) }
            let object = CanvasObject(
                kind: CanvasObjectKind(rawValue: item.kind) ?? .stickyNote,
                workspace: workspace,
                clip: clip,
                x: item.x,
                y: item.y,
                width: item.width,
                height: item.height,
                text: clip == nil ? item.text : "",
                style: CanvasObjectStyle(
                    fillHex: item.fillHex,
                    strokeHex: nil,
                    textHex: nil,
                    lineWidth: 0,
                    fontSize: 16
                )
            )
            context.insert(object)
            workspace.canvasObjects.append(object)
        }
        return workspace
    }

    private static func payload(for workspace: Workspace, includeImages: Bool) -> ClipCanvasWorkspaceSharePayload {
        ClipCanvasWorkspaceSharePayload(
            workspaceName: workspace.name,
            ownerName: workspace.ownerName ?? "Owner",
            sharedAt: Date(),
            objects: workspace.canvasObjects
                .filter(\.isCanvasContent)
                .sorted { $0.zIndex == $1.zIndex ? $0.createdAt < $1.createdAt : $0.zIndex < $1.zIndex }
                .map { object in
                    let clip = object.clip
                    return ClipCanvasWorkspaceSharePayload.SharedCanvasObject(
                        kind: object.kind.rawValue,
                        x: object.x,
                        y: object.y,
                        width: object.width,
                        height: object.height,
                        text: object.text,
                        clipContent: clip?.content,
                        clipType: clip?.type.rawValue,
                        imageDataBase64: includeImages ? clip?.imageData?.base64EncodedString() : nil,
                        imageUTI: includeImages ? clip?.imageUTI : nil,
                        fillHex: object.style.fillHex
                    )
                }
        )
    }

    private static func clip(from item: ClipCanvasWorkspaceSharePayload.SharedCanvasObject) -> Clip? {
        guard let content = item.clipContent else { return nil }
        let imageData = item.imageDataBase64.flatMap { Data(base64Encoded: $0) }
        return Clip(
            content: content,
            imageData: imageData,
            imageUTI: item.imageUTI,
            origin: .shared
        )
    }
}

private extension JSONEncoder {
    static var clipCanvasShare: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var clipCanvasShare: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
