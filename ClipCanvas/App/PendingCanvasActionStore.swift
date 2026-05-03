import Foundation

enum PendingCanvasActionStore {
    private static let pendingCopyKey = "clipcanvas.pendingCopyToCanvas"
    private static let pendingCopyMethodKey = "clipcanvas.pendingCopyToCanvasMethod"

    static func requestCopyToCanvas(method: CaptureMethod) {
        UserDefaults.standard.set(true, forKey: pendingCopyKey)
        UserDefaults.standard.set(method.rawValue, forKey: pendingCopyMethodKey)
    }

    static func consumeCopyToCanvasRequest() -> CaptureMethod? {
        guard UserDefaults.standard.bool(forKey: pendingCopyKey) else { return nil }
        UserDefaults.standard.set(false, forKey: pendingCopyKey)
        let rawValue = UserDefaults.standard.string(forKey: pendingCopyMethodKey)
        UserDefaults.standard.removeObject(forKey: pendingCopyMethodKey)
        return rawValue.flatMap(CaptureMethod.init(rawValue:)) ?? .quickAction
    }
}
