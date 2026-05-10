import Foundation
import Observation

enum AppRoute: Equatable {
    case canvas
    case copyToCanvas
    case library
    case workspace(UUID)
    case settings
}

@Observable
final class AppRouter {
    var pendingRoute: AppRoute?
    var pendingPasteMethod: CaptureMethod?

    func handle(url: URL) {
        switch url.host {
        case "copy-to-canvas", "capture":
            pendingRoute = .copyToCanvas
            pendingPasteMethod = .quickAction
        case "workspace":
            if let id = url.pathComponents.dropFirst().first.flatMap(UUID.init(uuidString:)) {
                pendingRoute = .workspace(id)
            } else {
                pendingRoute = .canvas
            }
        case "library":
            pendingRoute = .library
        case "settings":
            pendingRoute = .settings
        default:
            pendingRoute = .canvas
        }
    }

    func requestCopyToCanvas(method: CaptureMethod) {
        pendingRoute = .copyToCanvas
        pendingPasteMethod = method
    }
}
