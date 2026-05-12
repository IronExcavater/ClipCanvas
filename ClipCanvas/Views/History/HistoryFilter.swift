import Foundation
import Observation

enum HistoryTagFilter: Equatable {
    case builtIn(ClipType)
    case user(UUID)
}

@Observable
final class HistoryFilter {
    var search: String = ""
    var tag: HistoryTagFilter?

    func matches(_ clip: Clip) -> Bool {
        let matchesSearch = search.isEmpty
            || clip.content.localizedCaseInsensitiveContains(search)
        return matchesSearch && matchesTag(clip)
    }

    private func matchesTag(_ clip: Clip) -> Bool {
        guard let tag else { return true }
        switch tag {
        case .builtIn(let type):
            return clip.type == type
        case .user(let id):
            return clip.tags.contains { $0.id == id }
        }
    }
}
