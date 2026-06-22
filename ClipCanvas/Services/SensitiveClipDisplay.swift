import Combine
import Foundation

enum SensitiveClipDisplay {
    static func mask(for text: String) -> String {
        String(repeating: "•", count: maskLength(for: text))
    }

    static func maskLength(for text: String) -> Int {
        min(max(text.trimmingCharacters(in: .whitespacesAndNewlines).count, 6), 24)
    }
}

struct SensitiveTextPart: Hashable {
    let text: String
    let occurrence: Int

    var id: String {
        "\(occurrence)-\(text)"
    }
}

@MainActor
final class SensitiveTextRevealStore: ObservableObject {
    static let shared = SensitiveTextRevealStore()

    @Published private(set) var revealedPartIDs: Set<String> = []

    func isRevealed(_ partID: String) -> Bool {
        revealedPartIDs.contains(partID)
    }

    func toggle(_ partID: String) {
        if revealedPartIDs.contains(partID) {
            revealedPartIDs.remove(partID)
        } else {
            revealedPartIDs.insert(partID)
        }
    }
}

@MainActor
final class PrivateClipRevealStore: ObservableObject {
    static let shared = PrivateClipRevealStore()

    @Published private(set) var revealedUntil: [UUID: Date] = [:]

    private let revealDuration: TimeInterval

    init(revealDuration: TimeInterval = 60) {
        self.revealDuration = revealDuration
    }

    func isRevealed(_ clip: Clip, at date: Date = Date()) -> Bool {
        guard clip.isPrivateContent, let until = revealedUntil[clip.id] else { return false }
        return until > date
    }

    func toggle(_ clip: Clip, at date: Date = Date()) {
        if isRevealed(clip, at: date) {
            hide(clip)
        } else {
            reveal(clip, at: date)
        }
    }

    func reveal(_ clip: Clip, at date: Date = Date()) {
        guard clip.isPrivateContent else { return }
        let until = date.addingTimeInterval(revealDuration)
        revealedUntil[clip.id] = until
        scheduleExpiry(for: clip.id, until: until)
    }

    func hide(_ clip: Clip) {
        revealedUntil.removeValue(forKey: clip.id)
    }

    @discardableResult
    func purgeExpired(at date: Date = Date()) -> Int {
        let expiredIDs = revealedUntil
            .filter { $0.value <= date }
            .map(\.key)
        expiredIDs.forEach { revealedUntil.removeValue(forKey: $0) }
        return expiredIDs.count
    }

    private func scheduleExpiry(for id: UUID, until: Date) {
        let delay = max(until.timeIntervalSinceNow, 0)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                guard self?.revealedUntil[id] == until else { return }
                self?.revealedUntil.removeValue(forKey: id)
            }
        }
    }
}
