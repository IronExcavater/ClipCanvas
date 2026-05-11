import Foundation
import UIKit

// AppDelegate handles UIKit-level app lifecycle events that SwiftUI's App protocol
// doesn't expose — specifically, UIApplicationShortcutItem (3D Touch / long-press quick actions).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        switch shortcutItem.type {
        case "au.com.ironbyte.ClipCanvas.copyToCanvas":
            // Write to UserDefaults first in case SwiftUI hasn't initialised yet.
            PendingCanvasActionStore.requestCopyToCanvas(method: .quickAction)
            // Also post a notification so the router picks it up immediately if the app is already running.
            NotificationCenter.default.post(name: .copyToCanvasRequested, object: CaptureMethod.quickAction)
            completionHandler(true)
        default:
            completionHandler(false)
        }
    }
}

extension Notification.Name {
    // Custom notification name — using a reverse-DNS string avoids collisions with system names.
    static let copyToCanvasRequested = Notification.Name("clipcanvas.copyToCanvasRequested")
}
