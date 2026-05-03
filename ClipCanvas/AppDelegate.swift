import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        switch shortcutItem.type {
        case "au.com.ironbyte.ClipCanvas.copyToCanvas":
            PendingCanvasActionStore.requestCopyToCanvas(method: .quickAction)
            NotificationCenter.default.post(name: .copyToCanvasRequested, object: CaptureMethod.quickAction)
            completionHandler(true)
        default:
            completionHandler(false)
        }
    }
}

extension Notification.Name {
    static let copyToCanvasRequested = Notification.Name("clipcanvas.copyToCanvasRequested")
}
