import Foundation

extension Notification.Name {
    static let copyToCanvasRequested = Notification.Name("clipcanvas.copyToCanvasRequested")
    static let sharedTextReceived = Notification.Name("clipcanvas.sharedTextReceived")
}

#if canImport(UIKit)
import UIKit

// Handles UIKit-level app lifecycle events SwiftUI's App protocol doesn't expose —
// specifically Home Screen long-press quick actions. Available on iOS and visionOS,
// both of which share UIKit's app delegate model.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        switch shortcutItem.type {
        case "au.com.ironbyte.clipcanvas.app.copyToCanvas":
            // Write to the App Group first in case SwiftUI hasn't initialised yet.
            PendingCanvasActionStore.requestCopyToCanvas()
            // Also post a notification so the canvas picks it up immediately if already running.
            NotificationCenter.default.post(name: .copyToCanvasRequested, object: nil)
            completionHandler(true)
        default:
            completionHandler(false)
        }
    }
}

#elseif canImport(AppKit)
import AppKit

// macOS has no Home Screen, so the equivalent entry point is the Dock tile's
// right-click context menu (NSApplicationDelegate.applicationDockMenu).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(
            title: "Copy to Canvas",
            action: #selector(copyToCanvas),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func copyToCanvas() {
        PendingCanvasActionStore.requestCopyToCanvas()
        NotificationCenter.default.post(name: .copyToCanvasRequested, object: nil)
    }
}
#endif
