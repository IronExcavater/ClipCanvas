import Foundation

// Mirrors the write side of the main app's PendingCanvasActionStore. Kept as a separate,
// minimal copy rather than sharing the file across targets — the file-system-synchronized
// group for each target only auto-includes its own folder, and this extension only ever
// needs to write one key, so duplicating the App Group write is simpler than wiring up a
// cross-target membership exception in project.pbxproj.
enum PendingTextStore {
    private static let appGroupID = "group.au.com.ironbyte.ClipCanvas"
    private static let pendingSharedTextKey = "clipcanvas.pendingSharedText"

    static func savePendingText(_ text: String) {
        (UserDefaults(suiteName: appGroupID) ?? .standard).set(text, forKey: pendingSharedTextKey)
    }
}
