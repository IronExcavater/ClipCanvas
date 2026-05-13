import Foundation
import Observation

@Observable
final class HistoryFilter {
    var search: String = ""
    var type: ClipType?
    var userTagID: UUID?

    func matches(_ clip: Clip) -> Bool {
        let matchesSearch = search.isEmpty
            || clip.content.localizedCaseInsensitiveContains(search)
        let matchesType = type.map { clip.type == $0 } ?? true
        let matchesUserTag = userTagID.map { id in clip.tags.contains { $0.id == id } } ?? true
        return matchesSearch && matchesType && matchesUserTag
    }

    func clear() {
        type = nil
        userTagID = nil
    }
}
