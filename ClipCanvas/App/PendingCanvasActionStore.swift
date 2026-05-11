import Foundation

enum PendingCanvasActionStore {
    private static let pendingCopyKey = "clipcanvas.pendingCopyToCanvas"
    private static let pendingCopyMethodKey = "clipcanvas.pendingCopyToCanvasMethod"

    // Home-screen 3D Touch quick actions arrive through AppDelegate before SwiftUI has
    // finished initialising. Writing the request to UserDefaults here bridges the gap —
    // ClipCanvasApp reads it on the next scene activation and routes it to AppRouter.
    static func requestCopyToCanvas(method: CaptureMethod) {
        UserDefaults.standard.set(true, forKey: pendingCopyKey)
        UserDefaults.standard.set(method.rawValue, forKey: pendingCopyMethodKey)
    }

    // Returns the pending method and clears both UserDefaults keys atomically.
    // Returns nil if no request was pending (normal app launch path).
    static func consumeCopyToCanvasRequest() -> CaptureMethod? {
        guard UserDefaults.standard.bool(forKey: pendingCopyKey) else { return nil }
        UserDefaults.standard.set(false, forKey: pendingCopyKey)
        let rawValue = UserDefaults.standard.string(forKey: pendingCopyMethodKey)
        UserDefaults.standard.removeObject(forKey: pendingCopyMethodKey)
        return rawValue.flatMap(CaptureMethod.init(rawValue:)) ?? .quickAction
    }
}
