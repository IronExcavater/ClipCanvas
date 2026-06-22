import Foundation

// Bridges Quick Actions, Siri/App Intents, and the Share Extension to the main app via
// an App Group container — these run in separate processes from the main app, so they
// can't call into the running app's SwiftUI state directly. The main app drains this on
// every foreground (see ClipCanvasApp's scenePhase handling).
enum PendingCanvasActionStore {
    private static let appGroupID = "group.au.com.ironbyte.clipcanvas.app"
    private static var shared: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    private static let pendingCopyKey = "clipcanvas.pendingCopyToCanvas"
    private static let pendingSharedTextKey = "clipcanvas.pendingSharedText"

    // Home Screen quick action / Dock menu / Siri "copy clipboard" intent.
    static func requestCopyToCanvas() {
        shared.set(true, forKey: pendingCopyKey)
    }

    static func consumeCopyToCanvasRequest() -> Bool {
        guard shared.bool(forKey: pendingCopyKey) else { return false }
        shared.set(false, forKey: pendingCopyKey)
        return true
    }

    // Share Extension: pass specific text to the main app.
    static func savePendingText(_ text: String) {
        shared.set(text, forKey: pendingSharedTextKey)
    }

    static func consumePendingSharedText() -> String? {
        guard let text = shared.string(forKey: pendingSharedTextKey), !text.isEmpty else { return nil }
        shared.removeObject(forKey: pendingSharedTextKey)
        return text
    }
}
