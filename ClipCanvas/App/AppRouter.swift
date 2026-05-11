import Foundation
import Observation

enum AppRoute: Equatable {
    case canvas
    case copyToCanvas
    case library
    case workspace(UUID)
    case settings
}

// @Observable is Swift's observation framework — any view that reads a property of this class
// will automatically re-render when that property changes. It replaces the older
// ObservableObject + @Published pattern from UIKit-era SwiftUI.
@Observable
final class AppRouter {
    // Views read these and clear them once consumed. Keeping routing state here means
    // URL handlers and 3D Touch shortcuts don't need to reach into the view hierarchy.
    var pendingRoute: AppRoute?
    var pendingPasteMethod: CaptureMethod?

    func handle(url: URL) {
        // clipcanvas://copy-to-canvas  → paste clipboard to active workspace
        // clipcanvas://workspace/<uuid> → switch to a specific workspace
        // clipcanvas://library          → open the clip history sheet
        // clipcanvas://settings         → open settings
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
