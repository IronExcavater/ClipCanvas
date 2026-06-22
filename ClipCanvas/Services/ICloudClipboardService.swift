import Foundation

enum ICloudClipboardService {
    private static let textKey = "icloud.clipboard.text"
    private static let imageDataKey = "icloud.clipboard.imageData"
    private static let imageUTIKey = "icloud.clipboard.imageUTI"
    private static let updatedAtKey = "icloud.clipboard.updatedAt"
    private static let deviceIDKey = "icloud.clipboard.deviceID"
    private static let maxImageBytes = 512_000

    static func publish(_ content: ClipboardContent) {
        guard ICloudAccountService.currentStatus() == .available else { return }
        let store = NSUbiquitousKeyValueStore.default
        switch content {
        case .text(let text):
            store.set(text, forKey: textKey)
            store.removeObject(forKey: imageDataKey)
            store.removeObject(forKey: imageUTIKey)
        case .image(let data, let uti):
            guard data.count <= maxImageBytes else { return }
            store.set(data, forKey: imageDataKey)
            store.set(uti, forKey: imageUTIKey)
            store.removeObject(forKey: textKey)
        }
        store.set(Date().timeIntervalSince1970, forKey: updatedAtKey)
        store.set(deviceID, forKey: deviceIDKey)
        store.synchronize()
    }

    static func latestRemoteContent(after lastSeen: Date?) -> (content: ClipboardContent, date: Date)? {
        guard ICloudAccountService.currentStatus() == .available else { return nil }
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        guard store.string(forKey: deviceIDKey) != deviceID else { return nil }
        let timestamp = store.double(forKey: updatedAtKey)
        guard timestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        if let lastSeen, date <= lastSeen { return nil }
        if let text = store.string(forKey: textKey), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (.text(text), date)
        }
        if let data = store.data(forKey: imageDataKey) {
            return (.image(data, uti: store.string(forKey: imageUTIKey) ?? "public.png"), date)
        }
        return nil
    }

    private static var deviceID: String {
        let key = "settings.iCloudClipboardDeviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
